#!/usr/bin/env bash
# Runs the commands that the module pages and the playground guide teach and
# fails when one of them does not give the result the page describes.
# Every command is first looked up on its page and then run exactly as the
# page writes it, and every YAML file comes from the page, so the pages and
# this test cannot drift apart. scripts/ci/test-playground.sh runs it with
# KUBECONFIG set to the playground cluster.
set -euo pipefail
# Keep set -e inside $(...), so a failed page lookup also stops a captured command.
shopt -s inherit_errexit 2>/dev/null || true
cluster_name=astro-ats-035-playground-010-02
context="${ASTRONA_KUBE_CONTEXT:-kind-$cluster_name}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
playground_directory="$module_directory/playground"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT
# The pages save files in the current folder, so work in an empty one.
cd "$work_directory"
node_name="$cluster_name-control-plane"
worker_name="$cluster_name-worker"

# The pages run node commands as `podman exec "$worker_name" ...`. The kind
# nodes run on the engine named in ASTRONA_CONTAINER_ENGINE (Docker in CI), so
# send an exec on a node of this cluster there. Every other podman command runs
# the real podman.
podman() {
  if [[ "${1:-}" == exec && "${2:-}" == "$cluster_name"-* ]]; then
    command "$engine" "$@"
  else
    command podman "$@"
  fi
}

# Fail unless the page has this exact command in one of its ```sh blocks.
on_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, command = sys.argv[1:]
blocks = re.findall(r'```sh\n(.*?)```', open(page).read(), re.S)
if not any(command in block for block in blocks):
    sys.exit('the page ' + page + ' has no command: ' + command)
PY
}

# Run a command exactly as the page writes it.
page_run() {
  on_page "$1" "$2" || exit 1
  printf '$ %s\n' "$2" >&2
  eval "$2"
}

# Run a command that the page says must fail, and print its output.
page_fails() {
  local output
  on_page "$1" "$2" || exit 1
  printf '$ %s\n' "$2" >&2
  if output="$(eval "$2" 2>&1)"; then
    printf 'FAIL: the command succeeded, the page says it fails: %s\n%s\n' "$2" "$output" >&2
    exit 1
  fi
  printf '%s\n' "$output"
}

# Write the block that follows "Save this as `<file>`" (or "as `<file>`") on a
# page to <file> in the work folder. The third argument is the block language.
save_block_from_page() {
  python3 - "$module_directory/$1" "$2" "${3:-yaml}" "$work_directory/$2" <<'PY'
import re, sys
page, name, language, target = sys.argv[1:]
text = open(page).read()
match = re.search(r'as `' + re.escape(name) + r'`.*?```' + re.escape(language) + r'\n(.*?)```', text, re.S)
if not match:
    sys.exit('no ' + language + ' block for ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

save_yaml_from_page() {
  save_block_from_page "$1" "$2" yaml
}

# Write the YAML block from a page and apply it with the command the page uses.
save_from_page() {
  save_yaml_from_page "$1" "$2"
  page_run "$1" "kubectl apply -f $2"
}

# Print a phrase that the page states, and fail when the page no longer has it.
# A check uses it for the output the page promises, so a page edit that changes
# the promise also changes the check.
text_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import sys
page, phrase = sys.argv[1:]
if ' '.join(phrase.split()) not in ' '.join(open(page).read().split()):
    sys.exit('the page ' + page + ' does not say: ' + phrase)
print(phrase, end='')
PY
}

checks=0
expect() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == *"$3"* ]] || { printf 'FAIL: %s\nwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_equal() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" == "$3" ]] || { printf 'FAIL: %s\nwanted exactly: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

expect_no() {
  checks=$((checks + 1))
  printf 'check: %s\n' "$1"
  [[ "$2" != *"$3"* ]] || { printf 'FAIL: %s\nunwanted: %s\ngot: %s\n' "$1" "$3" "$2" >&2; exit 1; }
}

# Run a command until its output contains the text, at most about 2 minutes.
wait_for_output() {
  local wanted="$1" output='' attempt
  shift
  for attempt in $(seq 1 40); do
    output="$("$@" 2>&1 || true)"
    [[ "$output" == *"$wanted"* ]] && break
    sleep 3
  done
  printf '%s\n' "$output"
}

# The playground grader (validate.sh) must fail at the start, before any page
# step, and pass once the guide's steps are done.
if bash "$playground_directory/validate.sh" >/dev/null 2>&1; then
  printf 'FAIL: the playground grader passes before the guide steps\n' >&2
  exit 1
fi

# What each base image contains
page=course-01-what-each-base-image-contains.md
probe_contents="$(page_run "$page" "kubectl -n starfleet exec deploy/probe -- sh -c 'head -n 2 /etc/os-release; ls /lib/ld-musl*; apk info | wc -l'")"
printf '%s\n' "$probe_contents"
expect 'the first lines name Alpine Linux' "$(head -n 2 <<<"$probe_contents")" 'Alpine Linux'
expect 'ls lists the musl dynamic loader' "$(sed -n 3p <<<"$probe_contents")" '/lib/ld-musl'
expect 'the last line is a package count' "$(tail -1 <<<"$probe_contents" | tr -d ' ' | grep -cE '^[0-9]+$')" 1
shuttle_contents="$(page_run "$page" "kubectl -n starfleet exec shuttle -- sh -c 'ls -l /bin/sh; busybox | head -n 3; ls /bin | wc -l'")"
printf '%s\n' "$shuttle_contents"
expect 'sh is a link to busybox' "$(head -1 <<<"$shuttle_contents")" 'busybox'
expect 'busybox prints its version' "$shuttle_contents" 'BusyBox v1.37.0'
expect 'the last line is a count of commands' "$(tail -1 <<<"$shuttle_contents" | tr -d ' ' | grep -cE '^[0-9]+$')" 1
expect 'shuttle prints the fallback text' "$(page_run "$page" "kubectl -n starfleet exec shuttle -- sh -c 'which python || echo \"no python in this image\"'")" "$(text_from_page "$page" 'no python in this image')"
probe_python="$(page_run "$page" "kubectl -n starfleet exec deploy/probe -- sh -c 'which python && python --version'")"
printf '%s\n' "$probe_python"
expect 'probe prints the path of the interpreter' "$(head -1 <<<"$probe_python")" /python
expect 'probe prints the Python version' "$probe_python" 'Python 3.13'

# Measure what a running container can reach
page=course-02-measure-what-a-running-container-can-reach.md
defaults="$(page_run "$page" "kubectl -n starfleet exec shuttle -- sh -c 'id -u; grep -E \"^(CapEff|CapBnd|Seccomp):\" /proc/1/status'")"
printf '%s\n' "$defaults"
expect_equal 'shuttle runs as user ID 0' "$(head -1 <<<"$defaults")" 0
expect_no 'CapEff is not zero' "$(grep '^CapEff:' <<<"$defaults")" '0000000000000000'
expect_equal 'Seccomp is 0' "$(grep '^Seccomp:' <<<"$defaults" | awk '{print $2}')" 0
expect 'the root filesystem accepts a write' "$(page_run "$page" "kubectl -n starfleet exec shuttle -- sh -c 'touch /written-by-the-process && ls -l /written-by-the-process'")" '/written-by-the-process'
save_from_page "$page" pod-restricted-check.yaml
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/restricted-check --timeout=120s'
restricted="$(page_run "$page" "kubectl -n starfleet exec restricted-check -- sh -c 'id -u; grep -E \"^(CapEff|Seccomp):\" /proc/1/status'")"
printf '%s\n' "$restricted"
expect_equal 'restricted-check runs as user ID 10001' "$(head -1 <<<"$restricted")" 10001
expect_equal 'CapEff is all zeros' "$(grep '^CapEff:' <<<"$restricted" | awk '{print $2}')" 0000000000000000
expect_equal 'Seccomp is 2' "$(grep '^Seccomp:' <<<"$restricted" | awk '{print $2}')" 2
expect 'touch fails with a read-only file system error' "$(page_fails "$page" "kubectl -n starfleet exec restricted-check -- sh -c 'touch /written-by-the-process'")" 'Read-only file system'

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect 'shuttle is Running' "$(grep -E '^shuttle ' <<<"$pods")" Running
save_from_page "$page" pod-restricted-runner.yaml
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/restricted-runner --timeout=180s'
expect_equal 'the first command prints the user ID 10001' "$(page_run "$page" 'kubectl -n starfleet exec restricted-runner -- id -u')" 10001
expect 'touch prints an error and returns a nonzero status' "$(page_fails "$page" "kubectl -n starfleet exec restricted-runner -- sh -c 'touch /should-fail'")" 'Read-only file system'
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1 && echo validate-passed)" validate-passed

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
