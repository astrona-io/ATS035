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
address=$(kubectl -n "$namespace" get configmap registry-info -o jsonpath='{.data.server}')
image=$(kubectl -n "$namespace" get configmap registry-info -o jsonpath='{.data.image}')
kubectl -n "$namespace" create secret docker-registry registry-credentials --docker-server="$address" --docker-username=builder --docker-password=training-password --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$namespace" patch serviceaccount probe-runner --type=merge -p '{"imagePullSecrets":[{"name":"registry-credentials"}]}'
kubectl -n "$namespace" delete pod release-check --wait=true
kubectl -n "$namespace" run release-check --image="$image" --restart=Never --overrides='{"spec":{"serviceAccountName":"probe-runner","containers":[{"name":"client","image":"'"$image"'","imagePullPolicy":"Always","command":["sh","-c","sleep 36000"]}]}}'
kubectl -n "$namespace" wait --for=condition=Ready pod/release-check --timeout=180s
