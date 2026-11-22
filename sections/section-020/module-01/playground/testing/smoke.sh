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
cluster_name=astro-ats-035-playground-020-01
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

# Stages, trust boundaries and evidence
page=course-01-stages-trust-boundaries-and-evidence.md
references="$(page_run "$page" "kubectl get pods -A -o jsonpath='{range .items[*].spec.containers[*]}{.image}{\"\n\"}{end}' | sort -u")"
printf '%s\n' "$references"
expect 'the list has the python image' "$references" docker.io/library/python:3.13-alpine
expect 'the list has the busybox image' "$references" docker.io/library/busybox:1.37.0
for component in kube-apiserver etcd coredns; do
  expect "the list has the $component image from registry.k8s.io" "$(grep "$component" <<<"$references")" registry.k8s.io/
done
resolved="$(page_run "$page" "kubectl get pods -A -o jsonpath='{range .items[*].status.containerStatuses[*]}{.image}{\"  \"}{.imageID}{\"\n\"}{end}' | sort -u")"
printf '%s\n' "$resolved"
expect_equal 'each line pairs a reference with an imageID' "$(grep -cvE '^[^ ]+  ([^ ]+@)?sha256:[0-9a-f]{64}$' <<<"$resolved" || true)" 0

# Software bills of materials with Syft
page=course-02-software-bills-of-materials-with-syft.md
page_run "$page" 'syft scan docker.io/library/python:3.13-alpine \
  -o spdx-json=python.spdx.json \
  -o cyclonedx-json=python.cdx.json \
  -o syft-json=python.syft.json'
for document in python.spdx.json python.cdx.json python.syft.json; do
  expect "syft wrote $document" "$(python3 -c 'import json, sys; json.load(open(sys.argv[1])); print("valid JSON")' "$document")" 'valid JSON'
done
spdx_count="$(page_run "$page" "jq '.packages | length' python.spdx.json")"
cyclonedx_count="$(page_run "$page" "jq '.components | length' python.cdx.json")"
printf 'SPDX packages: %s, CycloneDX components: %s\n' "$spdx_count" "$cyclonedx_count"
expect_equal 'the SPDX document has one package entry for the image itself' "$(jq -r '[.packages[] | select(.name == "docker.io/library/python")] | length' python.spdx.json)" 1
cyclonedx_files="$(jq '[.components[] | select(.type == "file")] | length' python.cdx.json)"
printf 'CycloneDX components of type file: %s\n' "$cyclonedx_files"
expect_equal 'the CycloneDX count is many times larger than the SPDX count' "$((cyclonedx_count > 5 * spdx_count))" 1
expect_equal 'without its file components, CycloneDX has as many entries as SPDX' "$((cyclonedx_count - cyclonedx_files))" "$spdx_count"
# head stops reading after ten lines, so jq can exit on a closed pipe.
page_report "$page" "jq -r '.components[] | \"\\(.name) \\(.version)\"' python.cdx.json | head -n 10" >first-components.txt
cat first-components.txt
first_components="$(grep -v '^jq: error: writing output failed: Broken pipe$' first-components.txt || true)"
expect_equal 'the third command prints ten lines' "$(grep -c . <<<"$first_components")" 10
if [ "$(grep -c . first-components.txt)" != 10 ]; then
  expect 'the page names the message that jq prints on the closed pipe' "$(cat first-components.txt)" "$(text_from_page "$page" 'jq: error: writing output failed: Broken pipe')"
fi
expect_equal 'the SPDX name field holds the image reference' "$(jq -r .name python.spdx.json)" docker.io/library/python
page_run "$page" 'kubectl -n starfleet exec deploy/probe -- apk info -v | sort > apk-from-pod.txt'
cat apk-from-pod.txt
expect 'apk info -v prints each package with its version, such as musl' "$(grep '^musl-' apk-from-pod.txt)" 'musl-1.2.'
expect 'the list has the virtual package of the Python build' "$(cat apk-from-pod.txt)" "$(text_from_page "$page" '.python-rundeps-')"
expect_equal 'every other line has a name, a version and a release' "$(grep -v '^\.python-rundeps-' apk-from-pod.txt | grep -cvE '^.+-[^-]+-r[0-9]+$' || true)" 0
page_run "$page" "jq -r '.artifacts[] | select(.type == \"apk\") | \"\\(.name)-\\(.version)\"' python.syft.json | sort > apk-from-sbom.txt"
compared="$(page_run "$page" 'diff apk-from-pod.txt apk-from-sbom.txt && echo same')"
printf '%s\n' "$compared"
expect_equal 'diff prints nothing and the shell prints same' "$compared" "$(text_from_page "$page" same)"
probe_id="$(page_run "$page" "kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$probe_id"
expect 'the probe status has a digest' "$probe_id" 'sha256:'

# Vulnerability scanning with Trivy
page=course-03-vulnerability-scanning-with-trivy.md
page_run "$page" "running_image=\"\$(kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}')\""
echoed="$(page_run "$page" 'echo "$running_image"')"
printf '%s\n' "$echoed"
expect_equal 'the value is a repository digest or a sha256: image ID, as the page says' "$(grep -cE '^(docker\.io/library/python@)?sha256:[0-9a-f]{64}$' <<<"$echoed")" 1
# A pulled image reports the repository digest, which the page scans as it is.
# A preloaded image reports only a sha256: image ID; the page then says to use the tag.
if ! grep -qE '^docker\.io/library/python@sha256:[0-9a-f]{64}$' <<<"$echoed"; then
  text_from_page "$page" 'use the tag `docker.io/library/python:3.13-alpine` instead' >/dev/null
  running_image=docker.io/library/python:3.13-alpine
  printf 'only an image ID, so the scan uses the tag %s as the page says\n' "$running_image"
fi
page_report "$page" 'trivy image "$running_image"' >trivy-full.txt
tail -n 30 trivy-full.txt
expect_equal 'the full scan exits with code 0' "$report_status" 0
expect 'the output has a summary table' "$(cat trivy-full.txt)" 'Report Summary'
expect 'the summary has the operating system target' "$(cat trivy-full.txt)" '(alpine'
page_report "$page" 'trivy image --severity HIGH,CRITICAL --ignore-unfixed "$running_image"' >trivy-filtered.txt
tail -n 30 trivy-filtered.txt
expect_equal 'the filtered scan exits with code 0' "$report_status" 0
gate_output="$(page_report "$page" 'trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --format json --output trivy-report.json "$running_image"
echo "exit code: $?"')"
printf '%s\n' "$gate_output" | tail -n 3
expect 'the echo prints the exit code' "$gate_output" 'exit code: '
expect 'the report has a Results array' "$(jq -r '.Results | type' trivy-report.json)" array
remaining="$(jq '[.Results[].Vulnerabilities // [] | .[]] | length' trivy-report.json)"
printf 'findings left after the filters: %s\n' "$remaining"
if [[ "$remaining" == 0 ]]; then
  expect 'no finding remains, so the exit code is 0' "$gate_output" 'exit code: 0'
else
  expect 'findings remain, so the exit code is 1' "$gate_output" 'exit code: 1'
  expect_equal 'each finding has the fields the page names' "$(jq '[.Results[].Vulnerabilities // [] | .[] | select(has("VulnerabilityID") and has("PkgName") and has("InstalledVersion") and has("FixedVersion") and has("Severity") | not)] | length' trivy-report.json)" 0
fi
page_report "$page" 'trivy sbom --severity HIGH,CRITICAL --ignore-unfixed python.cdx.json' >trivy-sbom.txt
tail -n 30 trivy-sbom.txt
expect_equal 'the SBOM scan exits with code 0' "$report_status" 0
expect 'the SBOM scan has a summary table' "$(cat trivy-sbom.txt)" 'Report Summary'

# CI/CD pipelines and artifact repositories
page=course-04-ci-cd-pipelines-and-artifact-repositories.md
save_block_from_page "$page" dockerconfig.json json
expect_equal 'the auth value is the Base64 encoding of demo-user:demo-password' "$(printf 'demo-user:demo-password' | base64)" "$(python3 -c 'import json; print(json.load(open("dockerconfig.json"))["auths"]["registry.example"]["auth"])')"
page_run "$page" 'kubectl -n starfleet create secret generic registry-credentials \
  --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson=dockerconfig.json'
page_run "$page" "kubectl -n starfleet patch serviceaccount default -p '{\"imagePullSecrets\":[{\"name\":\"registry-credentials\"}]}'"
expect 'the first command prints the list with the Secret name' "$(page_run "$page" "kubectl -n starfleet get serviceaccount default -o jsonpath='{.imagePullSecrets}{\"\n\"}'")" '[{"name":"registry-credentials"}]'
expect_equal 'the second command prints the JSON you saved' "$(page_run "$page" "kubectl -n starfleet get secret registry-credentials -o jsonpath='{.data.\\.dockerconfigjson}' | base64 -d")" "$(cat dockerconfig.json)"
expect_equal 'the default ServiceAccount may not read Secrets' "$(page_fails "$page" 'kubectl auth can-i get secrets -n starfleet --as=system:serviceaccount:starfleet:default')" "$(text_from_page "$page" no)"
page_run "$page" "kubectl -n starfleet patch serviceaccount default -p '{\"imagePullSecrets\":null}'"
page_run "$page" 'kubectl -n starfleet delete secret registry-credentials'
expect_equal 'the ServiceAccount has no pull Secret after the clean-up' "$(kubectl -n starfleet get serviceaccount default -o jsonpath='{.imagePullSecrets}')" ''

# Make an SBOM of a running image in the cluster
page=course-05-make-an-sbom-of-a-running-image-in-the-cluster.md
probe_image="$(page_run "$page" "kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].image}{\" \"}{.items[0].status.containerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$probe_image"
expect_equal 'the line has the image name and a digest or a sha256: image ID' "$(grep -cE '^docker\.io/library/python:3\.13-alpine (docker\.io/library/python@)?sha256:[0-9a-f]{64}$' <<<"$probe_image")" 1
save_from_page "$page" job-sbom-probe.yaml
job_wait="$(page_run "$page" 'kubectl -n starfleet wait --for=condition=Complete job/sbom-probe --timeout=180s')"
printf '%s\n' "$job_wait"
expect_equal 'the wait reports the Complete condition' "$job_wait" "$(text_from_page "$page" 'job.batch/sbom-probe condition met')"
page_run "$page" 'kubectl -n starfleet logs job/sbom-probe -c syft > probe.cdx.json'
expect_equal 'the log is a CycloneDX document' "$(jq -r .bomFormat probe.cdx.json)" CycloneDX
tool="$(page_run "$page" "jq -r '.metadata.tools.components[] | \"\\(.name) \\(.version)\"' probe.cdx.json")"
printf '%s\n' "$tool"
expect_equal 'the document names the pinned Syft version' "$tool" "$(text_from_page "$page" 'syft 1.57.0')"
sbom_count="$(page_run "$page" "jq '[.components[] | select(.purl // \"\" | startswith(\"pkg:apk/\"))] | length' probe.cdx.json")"
pod_count="$(page_run "$page" "kubectl -n starfleet exec deploy/probe -- grep -c '^P:' /lib/apk/db/installed")"
printf '%s %s\n' "$sbom_count" "$pod_count"
expect_equal 'the SBOM has Alpine packages' "$(( sbom_count > 0 ))" 1
expect_equal 'the two numbers are equal' "$sbom_count" "$pod_count"
init_id="$(page_run "$page" "kubectl -n starfleet get pod -l job-name=sbom-probe -o jsonpath='{.items[0].status.initContainerStatuses[0].imageID}{\"\n\"}'")"
printf '%s\n' "$init_id"
expect_equal 'the init container ran the image ID of the probe pod' "$init_id" "${probe_image#* }"

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_yaml_from_page "$page" configmap-supply-inventory.yaml
save_block_from_page "$page" record-inventory.py python
page_run "$page" 'python3 record-inventory.py'
configmaps="$(page_run "$page" 'kubectl -n starfleet get configmaps')"
printf '%s\n' "$configmaps"
expect 'supply-inventory exists' "$configmaps" supply-inventory
expect 'the probe Deployment is kept' "$(page_run "$page" 'kubectl -n starfleet get deployment probe -o yaml')" 'readyReplicas: 2'
expect_equal 'the inventory scope is alpine-installed-packages' "$(kubectl -n starfleet get configmap supply-inventory -o jsonpath='{.data.scope}')" alpine-installed-packages
expect_equal 'the inventory packages are the sorted apk info -v lines' "$(kubectl -n starfleet get configmap supply-inventory -o jsonpath='{.data.packages}' | python3 -c 'import json, sys; print("\n".join(json.load(sys.stdin)))')" "$(LC_ALL=C sort apk-from-pod.txt)"
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1 && echo validate-passed)" validate-passed

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
