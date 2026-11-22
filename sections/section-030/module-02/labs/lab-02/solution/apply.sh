#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-030-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

kubectl apply -f "$solution_directory/namespace-starfleet.yaml"
kubectl apply -f "$solution_directory/validatingadmissionpolicy-release-gate.yaml"
kubectl apply -f "$solution_directory/validatingadmissionpolicybinding-release-gate.yaml"
kubectl get validatingadmissionpolicy release-gate -o jsonpath='{.status.typeChecking}{"\n"}'
# Admission does not check pods that already run; remove the one that breaks the rules.
kubectl -n starfleet-035-030-02-02 delete pod legacy-scout --wait=true --timeout=120s
