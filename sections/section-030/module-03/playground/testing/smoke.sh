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
cluster_name=astro-ats-035-playground-030-03
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

# Pull credentials for private registries
page=course-01-pull-credentials-for-private-registries.md
page_run "$page" 'kubectl create namespace pull-demo'
# read keeps the line continuations that $(cat <<'EOF') loses in bash 3.2.
IFS= read -r -d '' create_secret <<'EOF' || true
kubectl -n pull-demo create secret docker-registry registry-credentials \
  --docker-server=registry.example.com \
  --docker-username=reader \
  --docker-password=example-pass
EOF
create_secret="${create_secret%$'\n'}"
page_run "$page" "$create_secret"
expect_equal 'the Secret has the dockerconfigjson type' "$(page_run "$page" "kubectl -n pull-demo get secret registry-credentials -o jsonpath='{.type}{\"\n\"}'")" "$(text_from_page "$page" 'kubernetes.io/dockerconfigjson')"
decoded="$(page_run "$page" "kubectl -n pull-demo get secret registry-credentials -o jsonpath='{.data.\\.dockerconfigjson}' | base64 -d")"
printf '%s\n' "$decoded"
expect_equal 'the auths object has one entry, for registry.example.com' "$(jq -c '.auths | keys' <<<"$decoded")" '["registry.example.com"]'
expect_equal 'the entry holds the user name' "$(jq -r '.auths["registry.example.com"].username' <<<"$decoded")" reader
expect_equal 'the password is readable' "$(jq -r '.auths["registry.example.com"].password' <<<"$decoded")" example-pass
expect_equal 'auth is the base64 of user:password' "$(jq -r '.auths["registry.example.com"].auth' <<<"$decoded" | base64 -d)" reader:example-pass
save_from_page "$page" serviceaccount-puller.yaml
save_yaml_from_page "$page" pod-puller.yaml
expect_no 'the pod file does not mention the Secret' "$(cat pod-puller.yaml)" registry-credentials
expect 'the ServiceAccount admission plugin adds the Secret' "$(page_run "$page" "kubectl apply --dry-run=server -f pod-puller.yaml -o jsonpath='{.spec.imagePullSecrets}{\"\n\"}'")" '"name":"registry-credentials"'
page_run "$page" 'kubectl delete namespace pull-demo'

# The ImagePolicyWebhook admission plugin (node_name comes from the preamble)
page=course-02-the-imagepolicywebhook-admission-plugin.md
admission_lines="$(page_run "$page" "podman exec \"\$node_name\" grep -n 'admission' /etc/kubernetes/manifests/kube-apiserver.yaml")"
printf '%s\n' "$admission_lines"
expect 'the manifest has an --enable-admission-plugins line' "$admission_lines" '--enable-admission-plugins='
expect_no 'ImagePolicyWebhook is not enabled' "$admission_lines" ImagePolicyWebhook
apiserver_command="$(page_run "$page" "kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}{\"\n\"}'")"
printf '%s\n' "$apiserver_command"
expect 'the running API server shows enable-admission-plugins' "$apiserver_command" 'enable-admission-plugins'
expect_no 'the running API server has no ImagePolicyWebhook' "$apiserver_command" ImagePolicyWebhook
expect_no 'the running API server has no admission configuration file' "$apiserver_command" 'admission-control-config-file'

# Admission failure modes and exemptions
page=course-03-admission-failure-modes-and-exemptions.md
save_from_page "$page" failure-demo.yaml
save_yaml_from_page "$page" pod-unapproved.yaml
dry_run='kubectl apply --dry-run=server -f pod-unapproved.yaml'
# Audit has no visible effect, so give the binding time before the first run.
sleep 10
audited="$(page_run "$page" "$dry_run" 2>&1)"
printf '%s\n' "$audited"
expect 'with Audit the request is accepted' "$audited" 'pod/unapproved created (server dry run)'
expect_no 'with Audit no warning is printed' "$audited" 'Warning:'
page_run "$page" "kubectl patch validatingadmissionpolicybinding failure-demo --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/validationActions\",\"value\":[\"Warn\"]}]'"
wait_for_output 'Warning:' kubectl apply --dry-run=server -f pod-unapproved.yaml >/dev/null
warned="$(page_run "$page" "$dry_run" 2>&1)"
printf '%s\n' "$warned"
expect 'with Warn the request is still accepted' "$warned" 'pod/unapproved created (server dry run)'
expect 'with Warn a Warning: line carries the message' "$(grep '^Warning:' <<<"$warned")" 'image registry is not approved'
page_run "$page" "kubectl patch validatingadmissionpolicybinding failure-demo --type=json -p '[{\"op\":\"replace\",\"path\":\"/spec/validationActions\",\"value\":[\"Deny\"]}]'"
wait_for_output 'denied request' kubectl apply --dry-run=server -f pod-unapproved.yaml >/dev/null
denied="$(page_fails "$page" "$dry_run")"
printf '%s\n' "$denied"
expect 'with Deny the error names the policy' "$denied" "ValidatingAdmissionPolicy 'failure-demo'"
expect 'with Deny the error carries the message' "$denied" 'image registry is not approved'
page_run "$page" 'kubectl label namespace failure-demo training.astrona.io/failure-demo-'
wait_for_output 'created (server dry run)' kubectl apply --dry-run=server -f pod-unapproved.yaml >/dev/null
exempt="$(page_run "$page" "$dry_run" 2>&1)"
printf '%s\n' "$exempt"
expect 'without the label the request is accepted' "$exempt" 'pod/unapproved created (server dry run)'
expect_no 'without the label no warning is printed' "$exempt" 'Warning:'
page_run "$page" 'kubectl label namespace failure-demo training.astrona.io/failure-demo=enabled'
page_run "$page" 'kubectl delete -f failure-demo.yaml'
webhook_policies="$(page_run "$page" 'kubectl get validatingwebhookconfigurations -o custom-columns=NAME:.metadata.name,POLICY:.webhooks[*].failurePolicy' 2>&1)"
printf '%s\n' "$webhook_policies"
expect 'the playground has no webhook configuration' "$webhook_policies" 'No resources found'

# Playground guide
page=playground/docs/overview.md
deployer="$(page_run "$page" 'kubectl -n gated-images get serviceaccount deployer -o yaml')"
printf '%s\n' "$deployer"
expect_no 'deployer has no image pull secret yet' "$deployer" imagePullSecrets
binding="$(page_run "$page" 'kubectl get validatingadmissionpolicybinding gated-registry -o yaml')"
printf '%s\n' "$binding"
expect 'the binding only audits' "$binding" '- Audit'
expect_no 'the binding does not deny' "$binding" Deny
save_from_page "$page" binding-and-pull-secret.yaml
expect_equal 'the binding has the single action Deny' "$(page_run "$page" "kubectl get validatingadmissionpolicybinding gated-registry -o jsonpath='{.spec.validationActions}{\"\n\"}'")" '["Deny"]'
expect_equal 'deployer lists the Secret' "$(page_run "$page" "kubectl -n gated-images get serviceaccount deployer -o jsonpath='{.imagePullSecrets}{\"\n\"}'")" '[{"name":"registry-credentials"}]'
expect_equal 'the Secret has the dockerconfigjson type' "$(page_run "$page" "kubectl -n gated-images get secret registry-credentials -o jsonpath='{.type}{\"\n\"}'")" kubernetes.io/dockerconfigjson
# The guide describes two dry runs in prose. Run them with kubectl create
# --dry-run=server -f as it says.
cat >pod-gated-unapproved.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gated-unapproved
  namespace: gated-images
spec:
  containers:
  - name: app
    image: unapproved.example/reader:v1
EOF
cat >pod-gated-approved.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gated-approved
  namespace: gated-images
spec:
  serviceAccountName: deployer
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
EOF
gated_denied="$(wait_for_output 'denied request' kubectl create --dry-run=server -f pod-gated-unapproved.yaml)"
printf '%s\n' "$gated_denied"
expect 'the unapproved image fails with the policy message' "$gated_denied" "$(text_from_page "$page" 'image registry is not approved')"
gated_accepted="$(kubectl create --dry-run=server -f pod-gated-approved.yaml -o json)"
expect_equal 'the accepted pod lists the Secret' "$(jq -c '.spec.imagePullSecrets' <<<"$gated_accepted")" '[{"name":"registry-credentials"}]'
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
