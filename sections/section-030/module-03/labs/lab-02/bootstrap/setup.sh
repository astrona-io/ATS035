#!/usr/bin/env bash
# Starting state: the ImagePolicyWebhook files are on the control plane node,
# with defaultAllow: true, and the API server does not load the plugin yet.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-030-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
cluster="${ASTRONA_KIND_CLUSTER:-astro-ats-035-lab-030-03-02}"
engine="${ASTRONA_CONTAINER_ENGINE:-podman}"
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
node_name="$cluster-control-plane"
manifest=/etc/kubernetes/manifests/kube-apiserver.yaml

kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n starfleet-035-030-03-02 wait --for=condition=Ready pod/bridge --timeout=120s
kubectl -n outpost-035-030-03-02 wait --for=condition=Ready pod/drifter --timeout=120s

# The lab edits the plugin list that kubeadm writes; stop if it differs.
if ! "$engine" exec "$node_name" grep -qE '^ *- --enable-admission-plugins=NodeRestriction$' "$manifest"; then
  printf 'Unexpected kube-apiserver admission flags:\n' >&2
  "$engine" exec "$node_name" grep -n admission "$manifest" >&2 || true
  exit 1
fi

"$engine" exec "$node_name" mkdir -p /etc/kubernetes/admission
for file in admission-config.yaml backend.kubeconfig; do
  "$engine" exec -i "$node_name" sh -c "cat > /etc/kubernetes/admission/$file" <"$lab_directory/bootstrap/node/$file"
done
"$engine" exec "$node_name" chmod 0600 /etc/kubernetes/admission/admission-config.yaml /etc/kubernetes/admission/backend.kubeconfig
