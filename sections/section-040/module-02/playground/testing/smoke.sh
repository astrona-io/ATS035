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
cluster_name=astro-ats-035-playground-040-02
context="${ASTRONA_KUBE_CONTEXT:-kind-$cluster_name}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
module_directory="$(cd "$(dirname "$0")/../.." && pwd)"
playground_directory="$module_directory/playground"
work_directory="$(mktemp -d)"
# Tool output goes here, so that the folder scans see only the page files.
report_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory" "$report_directory"' EXIT
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

# What Trivy scans: the saved report, then Trivy on the host
page=course-01-what-trivy-scans-images-folders-and-configuration.md
report="$(page_run "$page" "kubectl -n starfleet get configmap scan-results -o jsonpath='{.data.results\.json}'")"
expect 'the report has an ArtifactName' "$report" '"ArtifactName"'
expect 'the report has a list of Results with a Target' "$report" '"Target"'
expect_equal 'the report lists five findings with the severities CRITICAL, HIGH, CRITICAL, LOW and HIGH' \
  "$(python3 -c 'import json,sys; print(", ".join(v["Severity"] for r in json.load(sys.stdin)["Results"] for v in r["Vulnerabilities"]))' <<<"$report")" \
  "$(text_from_page "$page" 'CRITICAL, HIGH, CRITICAL, LOW and HIGH' | sed 's/ and /, /')"
expect_equal 'one finding has an empty FixedVersion' \
  "$(python3 -c 'import json,sys; print(sum(1 for r in json.load(sys.stdin)["Results"] for v in r["Vulnerabilities"] if not v["FixedVersion"]))' <<<"$report")" 1
page_report "$page" 'trivy image --format json --output report.json docker.io/library/busybox:1.37.0' >"$report_directory/trivy-json.txt"
tail -n 5 "$report_directory/trivy-json.txt"
expect_equal 'the JSON scan exits with code 0' "$report_status" 0
expect_equal 'report.json has the ArtifactName of the image' "$(jq -r .ArtifactName report.json)" docker.io/library/busybox:1.37.0
expect_equal 'report.json has no Results list for busybox' "$(jq -r 'has("Results")' report.json)" false
save_yaml_from_page "$page" pod-risky-reader.yaml
expect 'the risky pod manifest is a valid object' "$(kubectl apply --dry-run=server -f pod-risky-reader.yaml)" 'pod/risky-reader created (server dry run)'
# The folder must hold only the pod file, as on the page.
rm report.json
page_report "$page" 'trivy config .' >"$report_directory/trivy-config.txt"
cat "$report_directory/trivy-config.txt"
expect_equal 'the configuration scan exits with code 0' "$report_status" 0
expect 'the configuration scan reports the privileged container' "$(cat "$report_directory/trivy-config.txt")" "Container 'reader' of Pod 'risky-reader' should set 'securityContext.privileged' to false"
expect 'the misconfiguration IDs start with KSV' "$(cat "$report_directory/trivy-config.txt")" 'KSV-'
page_report "$page" 'trivy fs --scanners vuln,secret .' >"$report_directory/trivy-fs.txt"
cat "$report_directory/trivy-fs.txt"
expect_equal 'the file system scan exits with code 0' "$report_status" 0
expect 'the file system scan finds no lock files' "$(cat "$report_directory/trivy-fs.txt")" 'Supported files for scanner(s) not found.'
expect 'the file system scan finds no secrets' "$(cat "$report_directory/trivy-fs.txt")" 'No issues detected with scanner(s).'

# Severity filters, unfixed findings and exit codes
page=course-02-severity-filters-unfixed-findings-and-exit-codes.md
gate_output="$(page_report "$page" 'trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 docker.io/library/busybox:1.37.0
echo "exit code: $?"')"
printf '%s\n' "$gate_output" | tail -n 12
expect 'the gate prints exit code 0 for busybox' "$gate_output" "$(text_from_page "$page" 'exit code: 0')"
expect 'Trivy finds no package database in busybox' "$gate_output" 'Supported files for scanner(s) not found.'
save_block_from_page "$page" count-blocking.py python
blocking_lines="$(page_run "$page" 'python3 count-blocking.py')"
printf '%s\n' "$blocking_lines"
expect_equal 'four lines appear' "$(grep -c . <<<"$blocking_lines")" 4
for identifier in FIXTURE-0001 FIXTURE-0002 FIXTURE-0005; do
  expect "$identifier prints as blocking" "$(grep "$identifier" <<<"$blocking_lines")" blocking
done
expect 'FIXTURE-0003 prints as unfixed' "$(grep FIXTURE-0003 <<<"$blocking_lines")" unfixed
expect_no 'FIXTURE-0004 is not listed' "$blocking_lines" FIXTURE-0004

# Exceptions, database freshness and what a finding proves
page=course-03-exceptions-database-freshness-and-what-a-finding-proves.md
version_output="$(page_run "$page" 'trivy version')"
printf '%s\n' "$version_output"
expect 'trivy version shows the vulnerability database' "$version_output" 'Vulnerability DB:'
expect 'trivy version shows when the database was updated' "$version_output" 'UpdatedAt:'
save_yaml_from_page "$page" .trivyignore.yaml
expect 'the YAML ignore file has an expiry date' "$(cat .trivyignore.yaml)" 'expired_at: 2026-12-31'
ignore_list="$(page_run "$page" "kubectl -n starfleet get configmap scan-exceptions -o jsonpath='{.data.trivyignore\.txt}'")"
printf '%s\n' "$ignore_list"
expect_equal 'the list holds one identifier, FIXTURE-0005' "$(grep -v '^#' <<<"$ignore_list" | grep .)" FIXTURE-0005
expect 'the comment names who accepted it' "$(grep '^#' <<<"$ignore_list")" 'platform team'

# Playground guide
page=playground/docs/overview.md
pods="$(page_run "$page" 'kubectl -n starfleet get pods -o wide')"
printf '%s\n' "$pods"
expect_equal 'two probe replicas are Running' "$(grep -E '^probe-' <<<"$pods" | grep -c Running)" 2
page_run "$page" 'kubectl get nodes -o wide'
save_block_from_page "$page" compute-scan-gate.py python
gate="$(page_run "$page" 'python3 compute-scan-gate.py')"
printf '%s\n' "$gate"
save_yaml_from_page "$page" configmap-scan-gate.yaml
expect_equal 'the values in the YAML file are the ones the script prints' \
  "$(python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))' <<<"$gate")" \
  "$(kubectl create --dry-run=client -f configmap-scan-gate.yaml -o json | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["data"], sort_keys=True))')"
page_run "$page" 'kubectl apply -f configmap-scan-gate.yaml'
recorded="$(page_run "$page" "kubectl -n starfleet get configmap scan-gate -o jsonpath='{.data}'")"
printf '%s\n' "$recorded"
expect_equal 'the recorded decision matches the script output' \
  "$(python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))' <<<"$recorded")" \
  "$(python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))' <<<"$gate")"
expect 'the playground grader passes after the guide steps' "$(bash "$playground_directory/validate.sh" 2>&1)" 'Required resource contract and behavior verified'

printf 'PASS: every page command gave the expected result (%s checks)\n' "$checks"
