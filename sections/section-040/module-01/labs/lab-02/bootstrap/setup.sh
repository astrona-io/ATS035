#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-040-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-035-040-01-02 wait --for=condition=Ready pod/linter --timeout=180s
kubectl -n starfleet-035-040-01-02 rollout status deployment/lint-probe --timeout=180s
kubectl -n outpost-035-040-01-02 wait --for=condition=Ready pod/drifter --timeout=120s
