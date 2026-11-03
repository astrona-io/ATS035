#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-035-lab-040-03-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/namespace-hangar.yaml"
kubectl -n hangar wait --for=condition=Ready pod/restricted-reader --timeout=180s
bash "$solution_directory/check-restricted.sh"
