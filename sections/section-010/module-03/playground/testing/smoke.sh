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
cluster_name=astro-ats-035-playground-010-03
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

# Pin images by digest and keep the pin current
page=course-01-pin-images-by-digest-and-keep-the-pin-current.md
probe_reference="$(page_run "$page" "kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].spec.containers[0].image}{\"\n\"}{.items[0].spec.containers[0].imagePullPolicy}{\"\n\"}{.items[0].status.containerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$probe_reference"
expect_equal 'the first line is the tag' "$(sed -n 1p <<<"$probe_reference")" docker.io/library/python:3.13-alpine
expect_equal 'the second line is IfNotPresent' "$(sed -n 2p <<<"$probe_reference")" "$(text_from_page "$page" IfNotPresent)"
expect 'the third line holds the image name, @sha256: and the digest' "$(sed -n 3p <<<"$probe_reference")" 'python@sha256:'
probe_digest="$(page_run "$page" "kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}' | sed 's/.*@sha256://'")"
printf '%s\n' "$probe_digest"
expect_equal 'the command prints the 64 characters of the digest alone' "$(grep -cE '^[0-9a-f]{64}$' <<<"$probe_digest")" 1
save_yaml_from_page "$page" deployment-pinned-probe.yaml
sed -i.bak "s/<PROBE_DIGEST>/$probe_digest/" deployment-pinned-probe.yaml
page_run "$page" 'kubectl apply -f deployment-pinned-probe.yaml'
page_run "$page" 'kubectl -n starfleet rollout status deployment/pinned-probe --timeout=120s'
pinned_id="$(page_run "$page" "kubectl -n starfleet get pod -l app=pinned-probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$pinned_id"
expect 'the last line ends with the copied digest' "$pinned_id" "sha256:$probe_digest"

# Pull policy, rebuild cadence and size budgets
page=course-02-pull-policy-rebuild-cadence-and-size-budgets.md
node_images="$(page_run "$page" 'podman exec "$worker_name" crictl images --digests')"
printf '%s\n' "$node_images"
expect 'the node holds the BusyBox image' "$node_images" 'docker.io/library/busybox'
expect 'the node holds the Python image' "$node_images" 'docker.io/library/python'
expect 'crictl shows a DIGEST column' "$(head -1 <<<"$node_images")" DIGEST
save_from_page "$page" pod-never-pull.yaml
never_status="$(wait_for_output ErrImageNeverPull kubectl -n starfleet get pod never-pull)"
on_page "$page" 'kubectl -n starfleet get pod never-pull'
printf '%s\n' "$never_status"
expect 'the status shows ErrImageNeverPull' "$never_status" "$(text_from_page "$page" ErrImageNeverPull)"
never_events="$(page_run "$page" 'kubectl -n starfleet describe pod never-pull | tail -n 8')"
printf '%s\n' "$never_events"
expect 'the events say that the image is not present with a pull policy of Never' "$never_events" 'is not present with pull policy of Never'
expect_no 'the node never contacted a registry' "$never_events" 'Pulling image'
page_run "$page" 'kubectl -n starfleet delete pod never-pull'

# Playground guide
page=playground/docs/overview.md
shuttle_id="$(page_run "$page" "kubectl -n starfleet get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$shuttle_id"
expect_equal 'the value has the form docker.io/library/busybox@sha256: and 64 characters' "$(grep -cE '^docker\.io/library/busybox@sha256:[0-9a-f]{64}$' <<<"$shuttle_id")" 1
shuttle_digest="$(page_run "$page" "kubectl -n starfleet get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}' | sed 's/.*@sha256://'")"
expect_equal 'the digest prints on its own' "$(grep -cE '^[0-9a-f]{64}$' <<<"$shuttle_digest")" 1
save_yaml_from_page "$page" pod-pinned-runner.yaml
sed -i.bak "s/<DIGEST>/$shuttle_digest/" pod-pinned-runner.yaml
page_run "$page" 'kubectl apply -f pod-pinned-runner.yaml'
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/pinned-runner --timeout=180s'
both_ids="$(page_run "$page" "kubectl -n starfleet get pod shuttle pinned-runner -o jsonpath='{range .items[*]}{.metadata.name}{\" \"}{.status.containerStatuses[0].imageID}{\"\n\"}{end}'")"
printf '%s\n' "$both_ids"
expect_equal 'both imageID values end in the same digest' "$(awk '{sub(/.*@sha256:/, "", $2); print $2}' <<<"$both_ids" | sort -u)" "$shuttle_digest"
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1 && echo validate-passed)" validate-passed

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
