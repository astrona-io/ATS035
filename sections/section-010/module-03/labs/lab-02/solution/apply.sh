#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-010-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-010-03-02

kubectl -n "$namespace" delete pod offline-runner --ignore-not-found --wait=true --timeout=120s
kubectl apply -f "$solution_directory/pod-offline-runner.yaml"
kubectl -n "$namespace" wait --for=condition=Ready pod/offline-runner --timeout=120s

kubectl apply -f "$solution_directory/deployment-relay.yaml"
kubectl -n "$namespace" rollout status deployment/relay --timeout=180s
