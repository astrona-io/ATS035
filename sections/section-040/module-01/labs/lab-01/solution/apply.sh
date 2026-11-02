#!/usr/bin/env bash
set -euo pipefail
if [[ "$(kubectl config current-context)" != "kind-astro-ats-035-lab-040-01-01" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
node_name="astro-ats-035-lab-040-01-01-control-plane"
worker_name="astro-ats-035-lab-040-01-01-worker"
python3 "$solution_directory/analyze-workload.py"
kubectl apply -f "$solution_directory/configmap-analysis-findings.yaml"
kubectl -n starfleet wait --for=condition=Ready pod/analyzed-reader --timeout=180s
