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
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-035-020-03-01 rollout status deployment/probe --timeout=180s
kubectl -n starfleet-035-020-03-01 wait --for=condition=Ready pod/shuttle --timeout=120s
kubectl -n outpost-035-020-03-01 wait --for=condition=Ready pod/drifter --timeout=120s


engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
namespace=starfleet-035-020-03-01
kubectl -n "$namespace" run password-hash --image=docker.io/library/httpd:2.4.65-alpine --restart=Never --command -- htpasswd -Bbn builder training-password
for attempt in $(seq 1 60); do
  phase=$(kubectl -n "$namespace" get pod password-hash -o jsonpath='{.status.phase}')
  [[ "$phase" != Failed ]] || exit 2
  [[ "$phase" != Succeeded ]] || break
  sleep 2
done
[[ "$phase" == Succeeded ]]
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
kubectl -n "$namespace" logs password-hash > "$work/htpasswd"
kubectl -n "$namespace" create secret generic registry-auth --from-file=htpasswd="$work/htpasswd"
kubectl -n "$namespace" apply -f "$lab_directory/bootstrap/manifests/registry.yaml"
kubectl -n "$namespace" rollout status deployment/registry --timeout=180s
address=$(kubectl get node "$node_name" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}'):32000
for node in "$node_name" "$worker_name"; do
  [[ "$("$engine" inspect --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}' "$node")" == "$cluster" ]]
  "$engine" exec "$node" mkdir -p "/etc/containerd/certs.d/$address"
  printf 'server = "http://%s"\n[host."http://%s"]\n  capabilities = ["pull", "resolve"]\n' "$address" "$address" |
    "$engine" exec -i "$node" tee "/etc/containerd/certs.d/$address/hosts.toml" >/dev/null
done
kubectl -n "$namespace" create configmap registry-info --from-literal=server="$address" --from-literal=image="$address/scout:v1"
kubectl -n "$namespace" create secret docker-registry registry-seed-auth --docker-server=registry:5000 --docker-username=builder --docker-password=training-password
kubectl -n "$namespace" apply -f "$lab_directory/bootstrap/manifests/seed.yaml"
kubectl -n "$namespace" wait --for=condition=complete job/seed-registry --timeout=240s
kubectl -n "$namespace" run release-check --image="$address/scout:v1" --restart=Never --overrides='{"spec":{"serviceAccountName":"probe-runner","containers":[{"name":"client","image":"'"$address"'/scout:v1","imagePullPolicy":"Always","command":["sh","-c","sleep 36000"]}]}}'
