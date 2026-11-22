#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-020-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-020-03-02

# Record the reference the pod asked for before it is changed.
kubectl apply -f "$solution_directory/configmap-pull-diagnosis.yaml"

kubectl -n "$namespace" set image deployment/scout client=docker.io/library/busybox:1.37.0
kubectl -n "$namespace" rollout status deployment/scout --timeout=180s

pod=""
for attempt in $(seq 1 24); do
  pod=$(kubectl -n "$namespace" get pods -l app=scout --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  [ -n "$pod" ] && break
  sleep 5
done
[ -n "$pod" ] || { printf 'No running scout pod\n' >&2; exit 1; }
requested=$(kubectl -n "$namespace" get pod "$pod" -o jsonpath='{.spec.containers[0].image}')
resolved=$(kubectl -n "$namespace" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].imageID}')
evidence=$(mktemp)
trap 'rm -f "$evidence"' EXIT
sed -e "s|<REQUESTED>|$requested|" -e "s|<IMAGE_ID>|$resolved|" "$solution_directory/configmap-pull-evidence.yaml" >"$evidence"
kubectl apply -f "$evidence"
kubectl -n "$namespace" get configmap pull-evidence -o jsonpath='{.data}{"\n"}'
