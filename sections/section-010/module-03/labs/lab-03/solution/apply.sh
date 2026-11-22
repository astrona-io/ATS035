#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-010-03-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-010-03-03
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

digest="$(kubectl -n "$namespace" get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}' | sed 's/.*@sha256://')"
echo "$digest"
sed "s/<DIGEST>/$digest/" "$solution_directory/deployment-minimal-web.yaml" >"$work/deployment-minimal-web.yaml"
kubectl apply -f "$work/deployment-minimal-web.yaml"
kubectl -n "$namespace" rollout status deployment/minimal-web --timeout=180s
kubectl -n "$namespace" exec deploy/minimal-web -- cat /sys/fs/cgroup/memory.max
kubectl apply -f "$solution_directory/service-minimal-web.yaml"
kubectl -n "$namespace" get endpointslices -l kubernetes.io/service-name=minimal-web
kubectl -n "$namespace" exec shuttle -- wget -qO- -T 5 http://minimal-web
