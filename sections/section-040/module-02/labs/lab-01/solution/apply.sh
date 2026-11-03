#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-035-lab-040-02-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
python3 "$solution_directory/compute-scan-gate.py" > /dev/null
kubectl apply -f "$solution_directory/configmap-scan-gate.yaml"
