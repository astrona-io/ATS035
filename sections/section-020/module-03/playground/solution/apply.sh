#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-playground-020-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-035-playground-020-03-control-plane"
worker_name="astro-ats-035-playground-020-03-worker"

kubectl apply -f "$solution_directory/registry-pull-access.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/release-check --timeout=180s
