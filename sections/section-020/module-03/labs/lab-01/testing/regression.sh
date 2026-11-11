#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-020-03-01}"
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-035-lab-020-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
worker_name="$cluster-worker"

namespace=starfleet-035-020-03-01
work=$(mktemp -d)
kubectl -n "$namespace" get secret registry-credentials -o json | python3 -c 'import json,sys; s=json.load(sys.stdin); s["metadata"]={"name":s["metadata"]["name"],"namespace":s["metadata"]["namespace"]}; print(json.dumps(s))' > "$work/credential.json"
restore() { kubectl apply -f "$work/credential.json" >/dev/null; rm -rf "$work"; }
trap restore EXIT
address=$(kubectl -n "$namespace" get configmap registry-info -o jsonpath='{.data.server}')
kubectl -n "$namespace" create secret docker-registry registry-credentials --docker-server="$address" --docker-username=builder --docker-password=incorrect --dry-run=client -o yaml | kubectl apply -f -
set +e
output=$(bash "$lab_directory/validation/validate-release-check.sh"); status=$?
set -e
printf '%s\n' "$output"
[[ "$status" == 1 && "$output" == 'FAIL: A fresh Pod must authenticate and pull the private image' ]]
restore
trap - EXIT
bash "$lab_directory/validation/validate-release-check.sh"
