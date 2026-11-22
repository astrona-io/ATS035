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
cluster_name=astro-ats-035-playground-030-02
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

# A digest rule with ValidatingAdmissionPolicy
page=course-01-a-digest-rule-with-validatingadmissionpolicy.md
save_from_page "$page" digest-demo-policy.yaml
sleep 5
type_checking="$(page_run "$page" "kubectl get validatingadmissionpolicy digest-demo -o jsonpath='{.status.typeChecking}{\"\n\"}'")"
printf '%s\n' "$type_checking"
expect_no 'the API server found no problem in the expressions' "$type_checking" 'fieldRef'
save_yaml_from_page "$page" pod-tag-only.yaml
save_yaml_from_page "$page" pod-pinned.yaml
# The binding needs a short time after creation before it takes effect.
wait_for_output 'Warning:' kubectl apply --dry-run=server -f pod-tag-only.yaml >/dev/null
tag_only="$(page_run "$page" 'kubectl apply --dry-run=server -f pod-tag-only.yaml' 2>&1)"
printf '%s\n' "$tag_only"
expect 'the tag-only pod is accepted' "$tag_only" 'pod/tag-only created (server dry run)'
expect 'a Warning: line carries the policy message' "$(grep '^Warning:' <<<"$tag_only")" 'every image must be referenced by digest'
pinned="$(page_run "$page" 'kubectl apply --dry-run=server -f pod-pinned.yaml' 2>&1)"
printf '%s\n' "$pinned"
expect 'the pinned pod is accepted' "$pinned" 'pod/pinned created (server dry run)'
expect_no 'the pinned pod prints no warning' "$pinned" 'Warning:'
page_run "$page" "kubectl patch validatingadmissionpolicybinding digest-demo --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/validationActions\",\"value\":[\"Deny\"]}]'"
wait_for_output 'denied request' kubectl apply --dry-run=server -f pod-tag-only.yaml >/dev/null
denied="$(page_fails "$page" 'kubectl apply --dry-run=server -f pod-tag-only.yaml')"
printf '%s\n' "$denied"
expect 'the error names the policy' "$denied" "ValidatingAdmissionPolicy 'digest-demo'"
expect 'the error names the binding' "$denied" "binding 'digest-demo'"
expect 'the error carries the message' "$denied" 'every image must be referenced by digest'
expect 'the pinned pod is still accepted' "$(page_run "$page" 'kubectl apply --dry-run=server -f pod-pinned.yaml' 2>&1)" 'pod/pinned created (server dry run)'
page_run "$page" 'kubectl delete -f digest-demo-policy.yaml'

# Signatures, attestations and keyless signing (the cosign commands use
# placeholders and are left out)
page=course-02-signatures-attestations-and-keyless-signing.md
shuttle_id="$(page_run "$page" "kubectl -n starfleet get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$shuttle_id"
expect_equal 'the field shows the repository form or an image identifier' "$(grep -cE '^(docker.io/library/busybox@)?sha256:[0-9a-f]{64}$' <<<"$shuttle_id")" 1

# Enforcing verification and its limits
page=course-03-enforcing-verification-and-its-limits.md
listing="$(page_run "$page" "kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{\"/\"}{.metadata.name}{\" \"}{.spec.containers[*].image}{\"\n\"}{end}'")"
printf '%s\n' "$listing"
expect_equal 'shuttle shows a tag and no digest' "$(grep '^starfleet/shuttle ' <<<"$listing")" 'starfleet/shuttle docker.io/library/busybox:1.37.0'
expect 'the listing has the pods of every namespace' "$listing" 'kube-system/'
webhooks="$(page_run "$page" 'kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations' 2>&1)"
printf '%s\n' "$webhooks"
expect 'the playground shows no image verification webhook' "$webhooks" 'No resources found'
policies="$(page_run "$page" 'kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding' 2>&1)"
printf '%s\n' "$policies"
expect 'no policy is left after the demo cleanup' "$policies" 'No resources found'

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
expect 'the namespace pinned-images does not exist yet' "$(page_fails "$page" 'kubectl get namespace pinned-images')" 'NotFound'
save_from_page "$page" namespace-pinned-images.yaml
sleep 5
expect_no 'the policy type-checks' "$(page_run "$page" "kubectl get validatingadmissionpolicy require-digest -o jsonpath='{.status.typeChecking}{\"\n\"}'")" 'fieldRef'
expect_equal 'the binding has the single action Deny' "$(page_run "$page" "kubectl get validatingadmissionpolicybinding require-digest -o jsonpath='{.spec.validationActions}{\"\n\"}'")" '["Deny"]'
# The guide describes three dry runs in prose. Run them with kubectl create
# --dry-run=server -f as it says.
write_pod() {
  cat >"$1" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: digest-check
  namespace: $2
spec:
  $4
  containers:
  - name: app
    image: $3
    command: ["sh", "-c", "sleep 3600"]
EOF
}
digest_image='docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
write_pod pod-tag-pinned-images.yaml pinned-images docker.io/library/busybox:1.37.0 ''
write_pod pod-digest-pinned-images.yaml pinned-images "$digest_image" ''
write_pod pod-tag-init-pinned-images.yaml pinned-images "$digest_image" 'initContainers: [{name: prepare, image: "docker.io/library/busybox:1.37.0", command: ["true"]}]'
write_pod pod-tag-starfleet.yaml starfleet docker.io/library/busybox:1.37.0 ''
tag_denied="$(wait_for_output 'must be referenced by digest' kubectl create --dry-run=server -f pod-tag-pinned-images.yaml)"
printf '%s\n' "$tag_denied"
expect 'a tag-only pod in pinned-images fails with the policy message' "$tag_denied" "$(text_from_page "$page" 'must be referenced by digest')"
expect 'a tag-only init container in pinned-images is rejected' "$(kubectl create --dry-run=server -f pod-tag-init-pinned-images.yaml 2>&1 || true)" 'must be referenced by digest'
expect 'a digest pod in pinned-images is accepted' "$(kubectl create --dry-run=server -f pod-digest-pinned-images.yaml 2>&1)" 'created (server dry run)'
expect 'the tag-only pod is accepted in starfleet' "$(kubectl create --dry-run=server -f pod-tag-starfleet.yaml 2>&1)" 'created (server dry run)'
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
