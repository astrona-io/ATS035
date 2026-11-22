#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-040-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/namespace-hangar.yaml"
kubectl apply -f "$solution_directory/deployment-cargo-loader.yaml"
kubectl -n hangar-035-040-03-02 rollout status deployment/cargo-loader --timeout=180s
# A privileged pod must now be rejected; the dry run creates nothing.
if kubectl apply --dry-run=server -f "$lab_directory/testing/privileged-check.yaml"; then
  printf 'The privileged pod was admitted\n' >&2
  exit 1
fi
