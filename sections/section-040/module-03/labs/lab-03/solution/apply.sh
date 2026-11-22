#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-040-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-040-03-03
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

kubectl -n "$namespace" get configmap analysis-source -o jsonpath='{.data.workload\.json}' |
  jq '{image: .spec.containers[0].image, pod: .spec.securityContext, container: .spec.containers[0].securityContext}'
kubectl -n "$namespace" create configmap analysis-findings \
  --from-literal=privileged=true \
  --from-literal=runAsNonRoot=missing \
  --from-literal=allowPrivilegeEscalation=missing \
  --from-literal=imageTag=latest

kubectl -n "$namespace" get configmap scan-results -o jsonpath='{.data.results\.json}' |
  jq -r '.Results[].Vulnerabilities[] | [.VulnerabilityID, .Severity, (if .FixedVersion == "" then "-" else .FixedVersion end)] | @tsv'
kubectl -n "$namespace" get configmap scan-exceptions -o jsonpath='{.data.trivyignore\.txt}'
kubectl -n "$namespace" create configmap scan-gate \
  --from-literal=decision=fail \
  --from-literal=blocking=FIXTURE-0001,FIXTURE-0002 \
  --from-literal=waived=FIXTURE-0005 \
  --from-literal=unfixed=FIXTURE-0003 \
  --from-literal=severity=HIGH,CRITICAL \
  --from-literal=ignoreUnfixed=true

kubectl label namespace "$namespace" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.35 \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
kubectl -n "$namespace" get configmap analysis-source -o jsonpath='{.data.workload\.json}' >"$work/workload.json"
kubectl apply --dry-run=server -f "$work/workload.json" || true

kubectl apply -f "$solution_directory/pod-corrected-reader.yaml"
kubectl -n "$namespace" wait --for=condition=Ready pod/corrected-reader --timeout=180s
