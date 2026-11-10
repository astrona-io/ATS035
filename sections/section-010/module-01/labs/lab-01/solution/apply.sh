#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-010-01-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-035-lab-010-01-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

kubectl apply -f "$solution_directory/configmap-minimal-content.yaml"
kubectl -n starfleet-035-010-01-01 wait --for=condition=Ready pod/minimal-server --timeout=180s
