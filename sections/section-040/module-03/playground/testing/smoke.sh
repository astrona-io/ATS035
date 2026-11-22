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
cluster_name=astro-ats-035-playground-040-03
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

# The Pod Security Standards
page=course-01-the-pod-security-standards.md
expect_no 'hangar starts with no PSA labels' "$(kubectl get namespace hangar -o jsonpath='{.metadata.labels}')" 'pod-security.kubernetes.io'
save_from_page "$page" namespace-trial.yaml
save_yaml_from_page "$page" pod-plain-reader.yaml
page_run "$page" 'kubectl apply -f pod-plain-reader.yaml'
kubectl -n trial wait --for=condition=Ready pod/plain-reader --timeout=120s
expect 'the plain pod is accepted at baseline' "$(page_run "$page" 'kubectl -n trial get pod plain-reader')" Running
preview="$(page_run "$page" 'kubectl label --dry-run=server --overwrite namespace trial pod-security.kubernetes.io/enforce=restricted' 2>&1)"
printf '%s\n' "$preview"
expect 'the warning names the existing pod plain-reader' "$preview" 'plain-reader:'
for field in allowPrivilegeEscalation capabilities runAsNonRoot seccompProfile; do
  expect "the warning lists $field" "$(grep 'plain-reader:' <<<"$preview")" "$field"
done
expect_equal 'nothing changes because of the dry run' "$(kubectl get namespace trial -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" baseline

# Namespace labels, modes and versions
page=course-02-namespace-labels-modes-and-versions.md
preview="$(page_run "$page" 'kubectl label --dry-run=server --overwrite namespace starfleet pod-security.kubernetes.io/enforce=restricted' 2>&1)"
printf '%s\n' "$preview"
expect 'the output is a warning about the existing pods' "$preview" 'Warning: existing pods in namespace "starfleet" violate the new PodSecurity enforce level "restricted:latest"'
expect 'the warning names the probe pods' "$preview" 'Warning: probe-'
expect 'the warning names the shuttle pod' "$preview" 'Warning: shuttle:'
expect 'the warning lists the fields that fail' "$preview" 'runAsNonRoot != true'
expect_no 'the label is not set' "$(kubectl get namespace starfleet -o jsonpath='{.metadata.labels}')" 'pod-security.kubernetes.io/enforce'
page_run "$page" 'kubectl label --overwrite namespace hangar pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted'
hangar_labels="$(page_run "$page" 'kubectl get namespace hangar --show-labels')"
printf '%s\n' "$hangar_labels"
expect 'hangar has the warn label' "$hangar_labels" 'pod-security.kubernetes.io/warn=restricted'
expect 'hangar has the audit label' "$hangar_labels" 'pod-security.kubernetes.io/audit=restricted'
expect_no 'hangar does not enforce yet' "$hangar_labels" 'pod-security.kubernetes.io/enforce='

# Meeting the restricted standard, exemptions and limits
page=course-03-meeting-restricted-exemptions-and-limits.md
save_from_page "$page" namespace-gate.yaml
save_yaml_from_page "$page" pod-failing-reader.yaml
rejected="$(page_fails "$page" 'kubectl apply -f pod-failing-reader.yaml')"
printf '%s\n' "$rejected"
expect 'the message contains the level and version' "$rejected" "$(text_from_page "$page" 'violates PodSecurity "restricted:v1.35"')"
for field in allowPrivilegeEscalation capabilities seccompProfile; do
  expect "the message lists $field" "$rejected" "$field"
done
expect_no 'the non-root setting is not listed' "$rejected" runAsNonRoot
save_yaml_from_page "$page" pod-passing-reader.yaml
page_run "$page" 'kubectl apply -f pod-passing-reader.yaml'
page_run "$page" 'kubectl -n gate wait --for=condition=Ready pod/passing-reader --timeout=120s'

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_from_page "$page" namespace-hangar.yaml
save_yaml_from_page "$page" pod-unrestricted-reader.yaml
rejected="$(page_fails "$page" 'kubectl apply -f pod-unrestricted-reader.yaml')"
printf '%s\n' "$rejected"
expect 'the error names the restricted level' "$rejected" 'violates PodSecurity "restricted:v1.35"'
expect 'the error names the rejected privileged field' "$rejected" 'privileged'
expect 'the unrestricted pod was not created' "$(kubectl -n hangar get pod unrestricted-reader 2>&1 || true)" NotFound
page_run "$page" 'kubectl -n hangar wait --for=condition=Ready pod/restricted-reader --timeout=180s'
hangar_labels="$(page_run "$page" 'kubectl get namespace hangar --show-labels')"
printf '%s\n' "$hangar_labels"
expect 'hangar enforces restricted' "$hangar_labels" 'pod-security.kubernetes.io/enforce=restricted'
expect 'hangar pins version v1.35' "$hangar_labels" 'pod-security.kubernetes.io/enforce-version=v1.35'
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
