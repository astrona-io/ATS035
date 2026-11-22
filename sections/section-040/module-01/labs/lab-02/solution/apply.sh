#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-040-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/deployment-lint-probe.yaml"
kubectl -n starfleet-035-040-01-02 rollout status deployment/lint-probe --timeout=180s
kubectl -n starfleet-035-040-01-02 get deployment lint-probe -o yaml |
  kubectl -n starfleet-035-040-01-02 exec -i linter -- /kube-linter lint --config /policy/kube-linter.yaml -
