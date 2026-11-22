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
cluster_name=astro-ats-035-playground-020-03
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

# Registries, repositories and who may push or pull
page=course-01-registries-repositories-and-who-may-push-or-pull.md
requested="$(page_run "$page" "kubectl -n starfleet get pods -o custom-columns='NAME:.metadata.name,REQUESTED:.spec.containers[0].image,POLICY:.spec.containers[0].imagePullPolicy'")"
printf '%s\n' "$requested"
expect 'the table has the columns NAME, REQUESTED and POLICY' "$(head -1 <<<"$requested")" 'REQUESTED'
expect_equal 'the table has one row for each pod' "$(($(wc -l <<<"$requested") - 1))" "$(kubectl -n starfleet get pods --no-headers | wc -l | tr -d ' ')"
expect 'shuttle requests busybox with the policy IfNotPresent' "$(grep -E '^shuttle ' <<<"$requested")" "$(text_from_page "$page" IfNotPresent)"
expect 'shuttle requests busybox:1.37.0' "$(grep -E '^shuttle ' <<<"$requested")" docker.io/library/busybox:1.37.0
expect 'probe requests python with the policy IfNotPresent' "$(grep -E '^probe-' <<<"$requested" | head -1)" 'docker.io/library/python:3.13-alpine'
resolved="$(page_run "$page" "kubectl -n starfleet get pods -o custom-columns='NAME:.metadata.name,RESOLVED:.status.containerStatuses[0].imageID'")"
printf '%s\n' "$resolved"
expect 'the RESOLVED column holds a sha256 identity for shuttle' "$(grep -E '^shuttle ' <<<"$resolved")" 'sha256:'
events="$(page_run "$page" 'kubectl -n starfleet get events --sort-by=.lastTimestamp')"
printf '%s\n' "$events" | tail -10
expect 'the events show normal start events' "$events" 'Started'
expect_no 'the healthy playground has no ErrImagePull' "$events" ErrImagePull
expect_no 'the healthy playground has no ImagePullBackOff' "$events" ImagePullBackOff

# Pull secrets and service accounts
page=course-02-pull-secrets-and-service-accounts.md
# read keeps the line continuations that $(cat <<'EOF') loses in bash 3.2.
IFS= read -r -d '' shape_command <<'EOF' || true
kubectl -n starfleet create secret docker-registry demo-credentials \
  --docker-server=registry.example.test \
  --docker-username=reader \
  --docker-password=example-password \
  --dry-run=client -o yaml
EOF
shape_command="${shape_command%$'\n'}"
shape="$(page_run "$page" "$shape_command")"
printf '%s\n' "$shape"
expect 'the dry run prints a Secret of type kubernetes.io/dockerconfigjson' "$shape" "$(text_from_page "$page" 'type: kubernetes.io/dockerconfigjson')"
expect 'the Secret has a .dockerconfigjson value' "$shape" '.dockerconfigjson: '
expect 'nothing was created in the cluster' "$(kubectl -n starfleet get secret demo-credentials 2>&1 || true)" NotFound
# read keeps the line continuations that $(cat <<'EOF') loses in bash 3.2.
IFS= read -r -d '' decode_command <<'EOF' || true
kubectl -n starfleet create secret docker-registry demo-credentials \
  --docker-server=registry.example.test \
  --docker-username=reader \
  --docker-password=example-password \
  --dry-run=client -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode
EOF
decode_command="${decode_command%$'\n'}"
decoded="$(page_run "$page" "$decode_command")"
printf '%s\n' "$decoded"
expect_equal 'auths is keyed by registry.example.test' "$(jq -r '.auths | keys[]' <<<"$decoded")" registry.example.test
expect_equal 'the entry holds the user' "$(jq -r '.auths["registry.example.test"].username' <<<"$decoded")" reader
expect_equal 'the entry holds the password' "$(jq -r '.auths["registry.example.test"].password' <<<"$decoded")" example-password
expect_equal 'the auth field is the Base64 encoding of user:password' "$(jq -r '.auths["registry.example.test"].auth' <<<"$decoded" | base64 --decode)" reader:example-password
account="$(page_run "$page" 'kubectl -n starfleet get serviceaccount probe-runner -o yaml')"
printf '%s\n' "$account"
expect_no 'probe-runner has no pull secrets at the start' "$account" imagePullSecrets
save_from_page "$page" serviceaccount-probe-runner.yaml
expect_equal 'the service account now names demo-credentials' "$(page_run "$page" "kubectl -n starfleet get serviceaccount probe-runner -o jsonpath='{.imagePullSecrets[*].name}{\"\n\"}'")" demo-credentials

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_from_page "$page" registry-pull-access.yaml
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/release-check --timeout=180s'
expect_equal 'the service account names registry-credentials' "$(page_run "$page" "kubectl -n starfleet get serviceaccount probe-runner -o jsonpath='{.imagePullSecrets[*].name}{\"\n\"}'")" registry-credentials
expect_equal 'the pod received the pull secret through its service account' "$(page_run "$page" "kubectl -n starfleet get pod release-check -o jsonpath='{.spec.imagePullSecrets[*].name}{\"\n\"}'")" registry-credentials
expect_equal 'the Secret has the type kubernetes.io/dockerconfigjson' "$(kubectl -n starfleet get secret registry-credentials -o jsonpath='{.type}')" kubernetes.io/dockerconfigjson
expect_equal 'the auth field matches builder:s3cret-pull-token' "$(kubectl -n starfleet get secret registry-credentials -o jsonpath='{.data.\.dockerconfigjson}' | base64 --decode | jq -r '.auths["registry.example.test"].auth' | base64 --decode)" builder:s3cret-pull-token
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
