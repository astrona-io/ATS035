#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-capstone-030}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-035-capstone-030-control-plane"
worker_name="astro-ats-035-capstone-030-worker"

kubectl apply -f "$solution_directory/supply-chain-policy-set.yaml"
kubectl get namespace release-line --show-labels
