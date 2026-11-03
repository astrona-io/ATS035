#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-035-capstone-040" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
kubectl apply -f "$solution_directory/pod-corrected-reader.yaml"
python3 "$solution_directory/compute-records.py"
kubectl -n bay wait --for=condition=Ready pod/corrected-reader --timeout=180s
