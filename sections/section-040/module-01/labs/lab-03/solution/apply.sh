#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-040-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-040-01-03
report="$(mktemp)"
trap 'rm -f "$report"' EXIT

scan_live_deployment() {
  kubectl -n "$namespace" get deployment score-probe -o yaml |
    kubectl -n "$namespace" exec -i scanner -- kubesec scan -
}

# The starting Deployment: Kubesec exits with a non-zero code.
scan_live_deployment | jq '.[0] | {score, message, critical: [.scoring.critical[]?.id]}' || true

kubectl apply -f "$solution_directory/deployment-score-probe.yaml"
kubectl -n "$namespace" rollout status deployment/score-probe --timeout=180s
scan_live_deployment >"$report"
jq '.[0] | {score, message, advise: [.scoring.advise[]?.id]}' "$report"
score="$(jq '.[0].score' "$report")"
kubectl -n "$namespace" create configmap kubesec-report \
  --from-literal=object=deployment/score-probe \
  --from-literal=score="$score" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$namespace" get configmap kubesec-report -o jsonpath='{.data}'
echo
