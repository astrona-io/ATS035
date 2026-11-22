#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-020-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
namespace=starfleet-035-020-01-02
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT

kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
kubectl -n "$namespace" wait --for=condition=Ready pod --all --timeout=180s
for pod in $(kubectl -n "$namespace" get pods -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n "$namespace" get pod "$pod" -o jsonpath='{range .status.initContainerStatuses[*]}{.name}{" "}{.image}{" "}{.imageID}{"\n"}{end}{range .status.containerStatuses[*]}{.name}{" "}{.image}{" "}{.imageID}{"\n"}{end}' |
    sed "s|^|$pod |"
done | sort >"$work_directory/inventory.txt"
kubectl -n "$namespace" create configmap image-inventory --from-file=containers="$work_directory/inventory.txt"
kubectl -n "$namespace" get configmap image-inventory -o jsonpath='{.data.containers}'
