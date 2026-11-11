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

# The API accepts the policy before admission caches necessarily observe it.
for attempt in $(seq 1 30); do
  if output=$(python3 "$lab_directory/testing/check.py" 2>&1); then
    printf '%s\n' "$output"
    exit 0
  fi
  sleep 1
done
printf '%s\n' "$output" >&2
exit 1
