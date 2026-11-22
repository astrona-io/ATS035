#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-020-01-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-020-01-03
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

image_id="$(kubectl -n "$namespace" get pods -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}')"
echo "$image_id"
sed "s|<IMAGE_ID>|$image_id|" "$solution_directory/job-sbom-probe.yaml" >"$work/job-sbom-probe.yaml"
kubectl apply -f "$work/job-sbom-probe.yaml"
kubectl -n "$namespace" wait --for=condition=Complete job/sbom-probe --timeout=180s
kubectl -n "$namespace" logs job/sbom-probe -c syft >"$work/probe.cdx.json"
jq -c '{bomFormat, specVersion, tools: [.metadata.tools.components[] | "\(.name) \(.version)"], subject: .metadata.component.name}' "$work/probe.cdx.json"
jq -r '.components[] | select(.purl // "" | startswith("pkg:apk/")) | "\(.name)@\(.version)"' "$work/probe.cdx.json" | sort >"$work/sbom-packages.txt"
wc -l <"$work/sbom-packages.txt"
kubectl -n "$namespace" create configmap probe-sbom \
  --from-file=sbom.cdx.json="$work/probe.cdx.json" \
  --from-literal=runtimeImageID="$image_id"
kubectl -n "$namespace" get configmap probe-sbom -o jsonpath='{.data.runtimeImageID}'
echo
