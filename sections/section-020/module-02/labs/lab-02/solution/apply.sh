#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-020-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-020-02-02
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT

kubectl -n "$namespace" rollout status deployment/probe --timeout=180s
pod="$(kubectl -n "$namespace" get pod -l app=probe -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "$namespace" wait --for=condition=Ready "pod/$pod" --timeout=120s
image_id="$(kubectl -n "$namespace" get pod "$pod" -o jsonpath='{.status.containerStatuses[?(@.name=="probe")].imageID}')"
image_digest="${image_id##*@}"
if [[ "$image_digest" != sha256:* ]]; then
  printf 'Unexpected imageID: %s\n' "$image_id" >&2
  exit 1
fi
for name in configmap-sbom-record configmap-vex-statement; do
  sed -e "s|<IMAGE_ID>|$image_id|" -e "s|<IMAGE_DIGEST>|$image_digest|" \
    "$solution_directory/$name.yaml" >"$work_directory/$name.yaml"
  kubectl apply -f "$work_directory/$name.yaml"
done
kubectl -n "$namespace" get configmap sbom-record vex-statement -o yaml
