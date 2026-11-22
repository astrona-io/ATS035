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
cluster_name=astro-ats-035-playground-010-01
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

# Layers, tags and digests
page=course-01-layers-tags-and-digests.md
shuttle_image="$(page_run "$page" "kubectl -n starfleet get pod shuttle -o jsonpath='{.spec.containers[0].image}{\"\n\"}{.status.containerStatuses[0].image}{\"\n\"}{.status.containerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$shuttle_image"
expect_equal 'first line is the tag of the pod specification' "$(sed -n 1p <<<"$shuttle_image")" docker.io/library/busybox:1.37.0
expect 'last line is an image ID or a repository digest' "$(sed -n 3p <<<"$shuttle_image")" 'sha256:'
probe_contents="$(page_run "$page" "kubectl -n starfleet exec deploy/probe -- sh -c 'cat /etc/os-release | head -n 2; apk info | wc -l; which python'")"
printf '%s\n' "$probe_contents"
expect 'probe shows the Alpine release name' "$probe_contents" 'Alpine Linux'
expect 'probe has a Python interpreter' "$(tail -1 <<<"$probe_contents")" /python
# `which python` prints nothing and exits 1 in BusyBox, so the line fails as a whole.
shuttle_contents="$(page_fails "$page" "kubectl -n starfleet exec shuttle -- sh -c 'ls /bin | wc -l; which python'")"
printf '%s\n' "$shuttle_contents"
expect_equal 'shuttle prints only the count of programs in /bin' "$(grep -cv '^command terminated' <<<"$shuttle_contents")" 1
node_images="$(page_run "$page" 'podman exec "$worker_name" crictl images --digests')"
printf '%s\n' "$node_images"
expect 'node lists the busybox image' "$node_images" 'docker.io/library/busybox'
expect 'node lists the python image' "$node_images" 'docker.io/library/python'
expect 'crictl shows a DIGEST column' "$(head -1 <<<"$node_images")" DIGEST

# Multi-stage builds and minimal base images (podman on the host)
page=course-02-multi-stage-builds-and-minimal-base-images.md
save_block_from_page "$page" main.go go
save_block_from_page "$page" Dockerfile.single dockerfile
save_block_from_page "$page" Dockerfile.multi dockerfile
page_run "$page" 'podman build -f Dockerfile.single -t scout:single .'
page_run "$page" 'podman build -f Dockerfile.multi -t scout:multi .'
page_run "$page" 'podman images scout'
single_size="$(command podman image inspect scout:single --format '{{.Size}}')"
multi_size="$(command podman image inspect scout:multi --format '{{.Size}}')"
printf 'scout:single %s bytes, scout:multi %s bytes\n' "$single_size" "$multi_size"
expect_equal 'scout:multi is smaller than scout:single by a large factor (10 or more)' "$((single_size / multi_size >= 10))" 1
page_run "$page" 'podman run -d --rm --name scout-multi -p 8080:8080 scout:multi'
scout_reply="$(wait_for_output scout curl -s http://127.0.0.1:8080)"
on_page "$page" 'curl http://127.0.0.1:8080'
expect_equal 'curl prints scout' "$(curl http://127.0.0.1:8080)" "$(text_from_page "$page" scout)"
no_shell="$(page_fails "$page" 'podman exec scout-multi sh')"
printf '%s\n' "$no_shell"
expect 'podman exec says the executable file was not found' "$no_shell" 'executable file'
expect 'podman exec says not found' "$no_shell" 'not found'
page_run "$page" 'podman stop scout-multi'
multi_history="$(page_run "$page" 'podman history scout:multi')"
printf '%s\n' "$multi_history"
multi_history_full="$(command podman history --no-trunc scout:multi)"
expect 'the multi-stage history has the layer of the copied binary' "$multi_history_full" 'in /scout'
expect_no 'the multi-stage history has no go build layer' "$multi_history_full" 'go build'
single_history="$(command podman history --no-trunc scout:single)"
expect 'the single-stage history shows the go build layer' "$single_history" 'go build'

# Hardening a Dockerfile (podman on the host; hadolint is left out)
page=course-03-hardening-a-dockerfile.md
save_block_from_page "$page" Dockerfile.leak dockerfile
save_block_from_page "$page" Dockerfile.secret dockerfile
printf 'practice-token\n' >token.txt
page_run "$page" 'podman build -f Dockerfile.leak -t leaky:1 .'
leaky_history="$(page_run "$page" 'podman history --no-trunc leaky:1')"
printf '%s\n' "$leaky_history"
expect 'the leaky history lists the copy of token.txt as its own layer' "$leaky_history" "$(text_from_page "$page" 'in /token.txt')"
expect 'the copy layer names the file by its hash' "$leaky_history" '#(nop) COPY file:'
expect_no 'the final leaky filesystem has no /token.txt' "$(command podman run --rm leaky:1 ls / 2>&1)" token.txt
page_run "$page" 'podman build -f Dockerfile.secret --secret id=token,src=token.txt -t safe:1 .'
safe_history="$(page_run "$page" 'podman history --no-trunc safe:1')"
printf '%s\n' "$safe_history"
expect 'the safe history shows the instruction with its mount option' "$safe_history" '--mount=type=secret,id=token'
expect_no 'the safe history does not show the secret content' "$safe_history" practice-token
command podman rmi -f scout:single scout:multi leaky:1 safe:1 >/dev/null

# Running minimal images in a cluster
page=course-04-running-minimal-images-in-a-cluster.md
save_from_page "$page" pod-web-check.yaml
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/web-check --timeout=120s'
expect 'id reports user ID 10001' "$(page_run "$page" 'kubectl -n starfleet exec web-check -- id')" 'uid=10001'
expect 'the write to /blocked fails with a read-only filesystem error' "$(page_fails "$page" 'kubectl -n starfleet exec web-check -- touch /blocked')" 'Read-only file system'
page_run "$page" 'kubectl -n starfleet exec web-check -- touch /tmp/allowed'
# The page opens an interactive shell in the ephemeral container. A CI job has
# no terminal, so kubectl starts the container and then cannot attach to it.
# The shell keeps running in the container, so run the page's ps there.
debug_output="$(page_run "$page" 'kubectl -n starfleet debug -it web-check --image=docker.io/library/busybox:1.37.0 --target=app -- sh' </dev/null 2>&1 || true)"
printf '%s\n' "$debug_output"
debugger="$(kubectl -n starfleet get pod web-check -o jsonpath='{.spec.ephemeralContainers[0].name}')"
wait_for_output startedAt kubectl -n starfleet get pod web-check -o jsonpath='{.status.ephemeralContainerStatuses[0].state.running}' >/dev/null
processes="$(wait_for_output 'sleep 3600' kubectl -n starfleet exec web-check -c "$debugger" -- ps)"
printf '%s\n' "$processes"
expect 'ps in the ephemeral container shows the sleep process of app' "$processes" 'sleep 3600'
expect 'the pod keeps the record of the ephemeral container' "$(kubectl -n starfleet get pod web-check -o jsonpath='{.spec.ephemeralContainers[*].image}')" docker.io/library/busybox:1.37.0
save_from_page "$page" pod-bad-image.yaml
bad_status="$(wait_for_output ImagePullBackOff kubectl -n starfleet get pod bad-image)"
on_page "$page" 'kubectl -n starfleet get pod bad-image'
printf '%s\n' "$bad_status"
expect 'STATUS later shows ImagePullBackOff' "$bad_status" "$(text_from_page "$page" ImagePullBackOff)"
bad_events="$(page_run "$page" 'kubectl -n starfleet describe pod bad-image')"
printf '%s\n' "$bad_events" | tail -8
expect 'the events have a Failed event' "$bad_events" 'Failed'
expect 'the Failed event names the unapproved host' "$bad_events" 'unapproved.example'
expect 'the events show ErrImagePull' "$bad_events" "$(text_from_page "$page" ErrImagePull)"
page_run "$page" 'kubectl -n starfleet delete pod bad-image --now'

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_from_page "$page" configmap-minimal-content.yaml
page_run "$page" 'kubectl -n starfleet wait --for=condition=Ready pod/minimal-server --timeout=180s'
server_ip="$(kubectl -n starfleet get pod minimal-server -o jsonpath='{.status.podIP}')"
expect 'the client receives the page' "$(kubectl -n starfleet exec shuttle -- wget -q -T 5 -O- "http://$server_ip:8080/")" "$(text_from_page "$page" minimal-version=v1)"
expect 'the container has no Python interpreter' "$(kubectl -n starfleet exec minimal-server -- sh -c 'which python || echo no-python')" no-python
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
