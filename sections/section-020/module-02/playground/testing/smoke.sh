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
cluster_name=astro-ats-035-playground-020-02
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

# Print the whole ```sh block of a page that contains the given line, so a
# block that is one script (here documents included) runs exactly as written.
block_from_page() {
  python3 - "$module_directory/$1" "$2" <<'PY'
import re, sys
page, line = sys.argv[1:]
blocks = [block for block in re.findall(r'```sh\n(.*?)```', open(page).read(), re.S) if line in block.splitlines()]
if len(blocks) != 1:
    sys.exit('the page ' + page + ' has no single block with the line: ' + line)
print(blocks[0], end='')
PY
}

# Reading SPDX and CycloneDX documents
page=course-01-reading-spdx-and-cyclonedx-documents.md
first_packages="$(page_run "$page" 'kubectl -n starfleet exec deploy/probe -- apk info -v | sort | head -n 5')"
printf '%s\n' "$first_packages"
expect_equal 'the output is five lines' "$(wc -l <<<"$first_packages" | tr -d ' ')" 5
package_lines="$(grep -cv '^\.python-rundeps-' <<<"$first_packages" || true)"
expect_equal 'each package line is a name followed by a version and release' "$(grep -cE '^.+-[^-]+-r[0-9]+$' <<<"$first_packages")" "$package_lines"
if grep -q '^\.python-rundeps-' <<<"$first_packages"; then
  expect 'the first line is the virtual package the page names' "$(head -1 <<<"$first_packages")" "$(text_from_page "$page" '.python-rundeps-')"
fi
purls="$(page_run "$page" "kubectl -n starfleet exec deploy/probe -- apk info -v | sort | head -n 5 | sed -E 's/^(.*)-([^-]+-r[0-9]+)\$/pkg:apk\\/alpine\\/\\1@\\2/'")"
printf '%s\n' "$purls"
expect_equal 'each package line has the form pkg:apk/alpine/<name>@<version>' "$(grep -cE '^pkg:apk/alpine/[^@]+@[^-]+-r[0-9]+$' <<<"$purls")" "$package_lines"
expect_equal 'sed leaves the virtual package line unchanged' "$(grep -c '^\.python-rundeps-' <<<"$purls" || true)" "$((5 - package_lines))"
package_count="$(page_run "$page" 'kubectl -n starfleet exec deploy/probe -- apk info -v | wc -l')"
printf '%s\n' "$package_count"
package_count="$(tr -d ' ' <<<"$package_count")"
expect_equal 'the count is a number' "$(grep -cE '^[0-9]+$' <<<"$package_count")" 1
scoped_block="$(block_from_page "$page" "pod=\$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].metadata.name}')")"
printf '$ %s\n' "$scoped_block" >&2
scoped_output="$(eval "$scoped_block")"
printf '%s\n' "$scoped_output"
expect_equal 'the script prints the component count' "$(tail -1 <<<"$scoped_output")" "componentCount=$package_count"
expect 'image-id.txt holds the image ID' "$(cat image-id.txt)" 'sha256:'
python3 - <<'PYTHON'
import json
from pathlib import Path
bom = json.loads(Path('bom.json').read_text())
packages = Path('packages.txt').read_text().splitlines()
assert bom['bomFormat'] == 'CycloneDX' and bom['specVersion'] == '1.5'
assert {c['name'] + '-' + c['version'] for c in bom['components']} == set(packages)
assert all(c['purl'] == 'pkg:apk/alpine/' + c['name'] + '@' + c['version'] for c in bom['components'])
PYTHON
expect 'bom.json has one component with a purl per package line' "$(jq -r '.components[].purl' bom.json | wc -l | tr -d ' ')" "$package_count"

# Matching an SBOM to vulnerabilities and an image digest (the syft and cosign
# commands use placeholders such as <registry> and are left out)
page=course-02-matching-an-sbom-to-vulnerabilities-and-an-image-digest.md
replicas="$(page_run "$page" "kubectl -n starfleet get pod -l app=probe -o jsonpath='{range .items[*]}{.metadata.name}{\" \"}{.status.containerStatuses[0].imageID}{\"\n\"}{end}'")"
printf '%s\n' "$replicas"
expect_equal 'one line for each probe pod' "$(grep -c '^probe-' <<<"$replicas")" 2
expect_equal 'both replicas show the same image ID' "$(awk '{print $2}' <<<"$replicas" | sort -u | wc -l | tr -d ' ')" 1
expect 'the image ID has a digest' "$replicas" 'sha256:'
expect_equal 'the specification holds a tag' "$(page_run "$page" "kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].image}{\"\n\"}'")" docker.io/library/python:3.13-alpine

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_block_from_page "$page" build-sbom-record.py python
page_run "$page" 'python3 build-sbom-record.py'
expect_equal 'componentCount is the number of installed packages' "$(page_run "$page" "kubectl -n starfleet get configmap sbom-record -o jsonpath='{.data.componentCount}{\"\n\"}'")" "$package_count"
expect_equal 'the subject is the imageID of a probe container' "$(kubectl -n starfleet get configmap sbom-record -o jsonpath='{.data.subject}')" "$(awk 'NR == 1 {print $2}' <<<"$replicas")"
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1 && echo validate-passed)" validate-passed

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
