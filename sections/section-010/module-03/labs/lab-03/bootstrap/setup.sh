#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-010-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
# The node pulls BusyBox from the registry, so allow time for it.
kubectl -n starfleet-035-010-03-03 wait --for=condition=Ready pod/shuttle --timeout=300s
kubectl -n outpost-035-010-03-03 wait --for=condition=Ready pod/drifter --timeout=180s
