#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-playground-030-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-035-playground-030-03-control-plane"
worker_name="astro-ats-035-playground-030-03-worker"

kubectl apply -f "$solution_directory/binding-and-pull-secret.yaml"
kubectl -n gated-images get serviceaccount deployer
