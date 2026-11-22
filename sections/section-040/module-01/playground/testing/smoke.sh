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
cluster_name=astro-ats-035-playground-040-01
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

# What static analysis can and cannot show
page=course-01-what-static-analysis-can-and-cannot-show.md
save_yaml_from_page "$page" pod-risky-shuttle.yaml
stored="$(page_run "$page" 'kubectl apply --dry-run=server -o yaml -f pod-risky-shuttle.yaml')"
expect 'the stored object has a dnsPolicy you did not write' "$stored" 'dnsPolicy:'
expect 'the stored object has a restartPolicy you did not write' "$stored" 'restartPolicy:'
expect 'the stored object has a serviceAccountName you did not write' "$stored" 'serviceAccountName:'
expect 'the stored object has the token volume' "$stored" 'kube-api-access-'
expect 'the server-side dry run does not create the pod' "$(kubectl -n starfleet get pod risky-shuttle 2>&1 || true)" 'NotFound'

# Scanning manifests with Kubesec and linting with KubeLinter: the commands
# need the kubesec and kube-linter tools, which the playground does not
# provide. Only the manifests are checked here: they must parse on the server.
page=course-02-scanning-manifests-with-kubesec.md
save_yaml_from_page "$page" deployment-weak-probe.yaml
save_yaml_from_page "$page" deployment-fixed-probe.yaml
expect 'the weak Deployment is a valid object' "$(kubectl apply --dry-run=server -f deployment-weak-probe.yaml)" 'deployment.apps/weak-probe created (server dry run)'
expect 'the fixed Deployment is a valid object' "$(kubectl apply --dry-run=server -f deployment-fixed-probe.yaml)" 'deployment.apps/fixed-probe created (server dry run)'
page=course-03-linting-manifests-with-kubelinter.md
save_yaml_from_page "$page" deployment-lint-probe.yaml
expect 'the lint Deployment is a valid object' "$(kubectl apply --dry-run=server -f deployment-lint-probe.yaml)" 'deployment.apps/lint-probe created (server dry run)'

# A release decision with image scans and Pod Security Admission
page=course-04-a-release-decision-with-image-scans-and-pod-security-admission.md
save_from_page "$page" namespace-release-check.yaml
save_yaml_from_page "$page" pod-privileged-shuttle.yaml
rejected="$(page_fails "$page" 'kubectl apply -f pod-privileged-shuttle.yaml')"
printf '%s\n' "$rejected"
expect 'the error says the pod violates PodSecurity restricted' "$rejected" 'violates PodSecurity "restricted:latest"'
expect 'the error lists privilege escalation' "$rejected" 'allowPrivilegeEscalation != false'
expect 'the error lists capabilities' "$rejected" 'unrestricted capabilities'
expect 'the error lists runAsNonRoot' "$rejected" 'runAsNonRoot != true'
expect 'the error lists the seccomp profile' "$rejected" 'seccompProfile'
expect 'no node saw the pod' "$(kubectl -n release-check get pod privileged-shuttle 2>&1 || true)" 'NotFound'
save_yaml_from_page "$page" pod-compliant-shuttle.yaml
page_run "$page" 'kubectl apply -f pod-compliant-shuttle.yaml'
kubectl -n release-check wait --for=condition=Ready pod/compliant-shuttle --timeout=120s
expect 'the compliant pod is accepted and starts' "$(page_run "$page" 'kubectl -n release-check get pod compliant-shuttle')" 'Running'
label_check="$(page_run "$page" 'kubectl label --dry-run=server --overwrite namespace starfleet pod-security.kubernetes.io/enforce=restricted' 2>&1)"
printf '%s\n' "$label_check"
expect 'the API server warns about starfleet pods that would not pass' "$label_check" 'Warning: existing pods in namespace "starfleet" violate the new PodSecurity enforce level "restricted:latest"'
expect 'the dry run does not change the namespace' "$(kubectl get namespace starfleet -o jsonpath='{.metadata.labels}')" '"project"'
expect_no 'the starfleet namespace still has no enforce label' "$(kubectl get namespace starfleet -o jsonpath='{.metadata.labels}')" 'pod-security.kubernetes.io/enforce'
page_run "$page" 'kubectl delete namespace release-check'

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_yaml_from_page "$page" configmap-analysis-findings.yaml
save_block_from_page "$page" analyze-workload.py python
page_run "$page" 'python3 analyze-workload.py'
expect_equal 'the analysis records privileged true and the two missing fields' "$(kubectl -n starfleet get configmap analysis-findings -o jsonpath='{.data.privileged} {.data.runAsNonRoot} {.data.allowPrivilegeEscalation}')" 'true missing missing'
page_run "$page" 'kubectl apply -f configmap-analysis-findings.yaml'
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/analyzed-reader --timeout=180s'
expect 'analyzed-reader runs as the non-root user' "$(kubectl -n starfleet exec analyzed-reader -- id)" 'uid=1000'
expect 'analyzed-reader has a read-only root filesystem' "$(kubectl -n starfleet exec analyzed-reader -- touch /blocked 2>&1 || true)" 'Read-only file system'
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
