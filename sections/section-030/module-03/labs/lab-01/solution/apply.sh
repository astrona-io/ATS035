#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-035-lab-030-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-035-lab-030-03-01-control-plane"
worker_name="astro-ats-035-lab-030-03-01-worker"

kubectl apply -f "$solution_directory/binding-and-pull-secret.yaml"
kubectl -n gated-images get serviceaccount deployer
