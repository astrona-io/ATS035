#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-035-playground-010-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-035-playground-010-01-control-plane"
worker_name="astro-ats-035-playground-010-01-worker"

kubectl apply -f "$solution_directory/configmap-minimal-content.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/minimal-server --timeout=180s
