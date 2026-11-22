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
cluster_name=astro-ats-035-playground-030-01
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

# Run a scanner or linter command as the page writes it and print its output,
# also when it exits with a non-zero code: these tools use the exit code to
# report findings. The exit code goes to report_status.
report_status=0
page_report() {
  local output
  on_page "$1" "$2" || exit 1
  printf '$ %s\n' "$2" >&2
  if output="$(set +e; eval "$2" 2>&1)"; then
    report_status=0
  else
    report_status=$?
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

# Write the YAML block that follows the first mention of `<file>` on a page,
# for pages that name the file without "Save this as".
save_yaml_after_mention() {
  python3 - "$module_directory/$1" "$2" "$work_directory/$2" <<'PY'
import re, sys
page, name, target = sys.argv[1:]
match = re.search(r'`' + re.escape(name) + r'`.*?```yaml\n(.*?)```', open(page).read(), re.S)
if not match:
    sys.exit('no YAML block after ' + name + ' in ' + page)
open(target, 'w').write(match.group(1))
PY
}

# Print the line of a ```sh block on a page that starts with the given text,
# for a command too long to repeat in this script.
line_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, start = sys.argv[1:]
for block in re.findall(r'```sh\n(.*?)```', open(page).read(), re.S):
    for line in block.splitlines():
        if line.startswith(start):
            print(line)
            sys.exit(0)
sys.exit('no command starting with ' + start + ' in ' + page)
PY
}

# The admission pipeline and ValidatingAdmissionPolicy
page=course-01-the-admission-pipeline-and-validatingadmissionpolicy.md
policies="$(page_run "$page" 'kubectl get validatingadmissionpolicies,validatingadmissionpolicybindings' 2>&1)"
printf '%s\n' "$policies"
expect 'a fresh playground has no policy' "$policies" 'No resources found'
webhooks="$(page_run "$page" 'kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations' 2>&1)"
printf '%s\n' "$webhooks"
expect 'a fresh playground has no webhook configuration' "$webhooks" 'No resources found'
admission="$(page_run "$page" "kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep -i admission")"
printf '%s\n' "$admission"
expect 'the output shows the --enable-admission-plugins argument' "$admission" "$(text_from_page "$page" '--enable-admission-plugins')="
expect_no 'ImagePolicyWebhook is not enabled' "$admission" ImagePolicyWebhook
failure_policy="$(page_run "$page" 'kubectl explain validatingadmissionpolicy.spec.failurePolicy')"
expect 'explain documents failurePolicy' "$failure_policy" 'FIELD: failurePolicy'
expect 'failurePolicy has the value Ignore' "$failure_policy" Ignore
actions="$(page_run "$page" 'kubectl explain validatingadmissionpolicybinding.spec.validationActions')"
expect 'explain documents validationActions' "$actions" 'FIELD: validationActions'
for action in Deny Warn Audit; do
  expect "validationActions has the value $action" "$actions" "$action"
done

# Enforcing permitted registries
page=course-02-enforcing-permitted-registries.md
save_from_page "$page" registry-demo-policy.yaml
sleep 5
type_checking="$(page_run "$page" "kubectl get validatingadmissionpolicy demo-registry -o jsonpath='{.status.typeChecking}{\"\n\"}'")"
printf '%s\n' "$type_checking"
expect_no 'the expressions type-check without warnings' "$type_checking" 'fieldRef'
save_yaml_after_mention "$page" pod-good-registry.yaml
save_yaml_after_mention "$page" pod-bad-registry.yaml
expect 'the good pod is created in dry-run mode' "$(page_run "$page" 'kubectl apply --dry-run=server -f pod-good-registry.yaml' 2>&1)" 'pod/good-registry created (server dry run)'
# The binding needs a short time after creation before it takes effect.
wait_for_output 'Warning:' kubectl apply --dry-run=server -f pod-bad-registry.yaml >/dev/null
warned="$(page_run "$page" 'kubectl apply --dry-run=server -f pod-bad-registry.yaml' 2>&1)"
printf '%s\n' "$warned"
expect 'the bad pod is still created in dry-run mode' "$warned" 'pod/bad-registry created (server dry run)'
expect 'a Warning: line carries the policy message' "$(grep '^Warning:' <<<"$warned")" 'every image must start with docker.io/library/ or registry.k8s.io/'
page_run "$page" "kubectl patch validatingadmissionpolicybinding demo-registry --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/validationActions\",\"value\":[\"Deny\"]}]'"
wait_for_output 'denied request' kubectl apply --dry-run=server -f pod-bad-registry.yaml >/dev/null
denied="$(page_fails "$page" 'kubectl apply --dry-run=server -f pod-bad-registry.yaml')"
printf '%s\n' "$denied"
expect 'the error names the policy' "$denied" "ValidatingAdmissionPolicy 'demo-registry'"
expect 'the error names the binding' "$denied" "binding 'demo-registry'"
expect 'the error carries the message' "$denied" 'every image must start with docker.io/library/ or registry.k8s.io/'
save_from_page "$page" deployment-bad-registry.yaml
events="$(wait_for_output 'denied request' kubectl -n registry-demo get events --field-selector reason=FailedCreate)"
deployment="$(page_run "$page" 'kubectl -n registry-demo get deployment bad-deploy')"
printf '%s\n' "$deployment"
expect 'the Deployment shows zero ready replicas' "$(grep '^bad-deploy' <<<"$deployment")" '0/1'
events="$(page_run "$page" 'kubectl -n registry-demo get events --field-selector reason=FailedCreate')"
printf '%s\n' "$events"
expect 'the FailedCreate event carries the policy message' "$events" 'every image must start with docker.io/library/ or registry.k8s.io/'
page_run "$page" 'kubectl delete -f deployment-bad-registry.yaml'
page_run "$page" 'kubectl delete -f registry-demo-policy.yaml'

# Policy engines and admission webhooks
page=course-03-policy-engines-and-admission-webhooks.md
save_from_page "$page" webhook-unreachable.yaml
save_yaml_from_page "$page" pod-webhook-test.yaml
wait_for_output 'failed calling webhook' kubectl apply --dry-run=server -f pod-webhook-test.yaml >/dev/null
webhook_error="$(page_fails "$page" 'kubectl apply --dry-run=server -f pod-webhook-test.yaml')"
printf '%s\n' "$webhook_error"
expect 'the error says the call to the webhook failed' "$webhook_error" 'failed calling webhook "unreachable.demo.example"'
expect 'the error names the missing Service' "$webhook_error" 'service "missing" not found'
page_run "$page" "kubectl patch validatingwebhookconfiguration unreachable-demo --type=json -p '[{\"op\":\"replace\",\"path\":\"/webhooks/0/failurePolicy\",\"value\":\"Ignore\"}]'"
wait_for_output 'created (server dry run)' kubectl apply --dry-run=server -f pod-webhook-test.yaml >/dev/null
expect 'with Ignore the pod is accepted' "$(page_run "$page" 'kubectl apply --dry-run=server -f pod-webhook-test.yaml' 2>&1)" 'pod/webhook-test created (server dry run)'
page_run "$page" 'kubectl delete -f webhook-unreachable.yaml'

# Signing and verifying images with cosign (podman and cosign on the host)
page=course-04-signing-and-verifying-images-with-cosign.md
page_run "$page" 'podman run -d --name local-registry -p 5000:5000 docker.io/library/registry:2'
wait_for_output '{}' curl -s http://127.0.0.1:5000/v2/ >/dev/null
page_run "$page" 'podman pull docker.io/library/busybox:1.37.0'
page_run "$page" 'podman tag docker.io/library/busybox:1.37.0 localhost:5000/starfleet/shuttle:1.0'
page_run "$page" 'podman push --tls-verify=false --digestfile shuttle.digest localhost:5000/starfleet/shuttle:1.0'
digest="$(page_run "$page" 'cat shuttle.digest')"
printf '%s\n' "$digest"
expect_equal 'shuttle.digest holds sha256: and 64 hexadecimal characters' "$(grep -cE '^sha256:[0-9a-f]{64}$' <<<"$digest")" 1
# cosign reads the password from COSIGN_PASSWORD when no terminal can ask for it.
export COSIGN_PASSWORD=smoke-test-password
key_output="$(page_run "$page" 'cosign generate-key-pair' </dev/null 2>&1)"
printf '%s\n' "$key_output"
expect 'cosign writes the private key' "$key_output" 'Private key written to cosign.key'
expect 'cosign writes the public key' "$key_output" 'Public key written to cosign.pub'
sign_output="$(page_run "$page" 'cosign sign --key cosign.key --allow-insecure-registry --tlog-upload=false "localhost:5000/starfleet/shuttle@$(cat shuttle.digest)"' </dev/null 2>&1)"
printf '%s\n' "$sign_output"
expect 'cosign pushes the signature to the registry' "$sign_output" 'Pushing signature to: localhost:5000/starfleet/shuttle'
verify_output="$(page_run "$page" 'cosign verify --key cosign.pub --allow-insecure-registry --insecure-ignore-tlog=true "localhost:5000/starfleet/shuttle@$(cat shuttle.digest)"' </dev/null 2>&1)"
printf '%s\n' "$verify_output"
expect 'the verification lists the signature check' "$verify_output" 'The signatures were verified against the specified public key'
expect 'the payload names the repository' "$verify_output" '"docker-reference":"localhost:5000/starfleet/shuttle"'
expect 'the payload names the signed digest' "$verify_output" "\"docker-manifest-digest\":\"$(cat shuttle.digest)\""
page_run "$page" 'podman tag docker.io/library/busybox:1.37.0 localhost:5000/starfleet/other:1.0'
page_run "$page" 'podman push --tls-verify=false localhost:5000/starfleet/other:1.0'
expect 'the second repository holds the same content' "$(curl -s -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' -o /dev/null -w '%{http_code}' "http://127.0.0.1:5000/v2/starfleet/other/manifests/$(cat shuttle.digest)")" 200
other_output="$(page_fails "$page" 'cosign verify --key cosign.pub --allow-insecure-registry --insecure-ignore-tlog=true "localhost:5000/starfleet/other@$(cat shuttle.digest)"' </dev/null)"
printf '%s\n' "$other_output"
expect 'the verification in the second repository finds no signatures' "$other_output" "$(text_from_page "$page" 'no signatures found')"
page_run "$page" 'podman rm -f local-registry'

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_from_page "$page" namespace-approved-images.yaml
page_run "$page" 'kubectl -n approved-images wait --for=condition=Ready pod/approved-reader --timeout=180s'
denial_check="$(line_from_page "$page" 'python3 -c ')"
# The binding needs a short time after creation before it takes effect.
wait_for_output unapproved-image-denied bash -c "$denial_check" >/dev/null
expect_equal 'the unapproved image is denied with the policy message' "$(page_run "$page" "$denial_check")" unapproved-image-denied
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
