#!/usr/bin/env bash
# Reference solution: fail closed, load the plugin and mount its files, then
# wait until the restarted API server rejects a new pod through the backend.
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
edit=/etc/kubernetes/edit/kube-apiserver.yaml

"$engine" exec -i "$node_name" sh -c 'cat > /etc/kubernetes/admission/admission-config.yaml' <"$lab_directory/solution/admission-config.yaml"

# Edit a copy outside the manifests directory, check it, then move it back.
"$engine" exec "$node_name" mkdir -p /etc/kubernetes/edit
"$engine" exec "$node_name" cp -p "$manifest" /etc/kubernetes/kube-apiserver.yaml.backup
"$engine" exec "$node_name" cp -p "$manifest" "$edit"
"$engine" exec "$node_name" sed -i \
  -e 's|^\( *\)- --enable-admission-plugins=NodeRestriction$|\1- --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook\n\1- --admission-control-config-file=/etc/kubernetes/admission/admission-config.yaml|' \
  -e 's|^\( *\)volumeMounts:$|&\n\1- mountPath: /etc/kubernetes/admission\n\1  name: image-policy\n\1  readOnly: true|' \
  -e 's|^\( *\)volumes:$|&\n\1- hostPath:\n\1    path: /etc/kubernetes/admission\n\1    type: DirectoryOrCreate\n\1  name: image-policy|' \
  "$edit"
for pattern in 'NodeRestriction,ImagePolicyWebhook' 'admission-control-config-file=/etc/kubernetes/admission/admission-config.yaml' 'mountPath: /etc/kubernetes/admission' 'path: /etc/kubernetes/admission'; do
  if ! "$engine" exec "$node_name" grep -qF -- "$pattern" "$edit"; then
    printf 'The edited manifest is missing: %s\n' "$pattern" >&2
    exit 1
  fi
done
"$engine" exec "$node_name" mv "$edit" "$manifest"

# The kubelet restarts the API server. Wait, with a deadline, until a server
# dry run of a new pod is rejected because the backend cannot be reached.
deadline=$((SECONDS + 300))
until output="$(kubectl -n starfleet-035-030-03-02 run image-check --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server --request-timeout=15s -o name 2>&1)"; [[ "$output" == *orbidden*9443* ]]; do
  if (( SECONDS > deadline )); then
    printf 'Timed out waiting for the API server to reject pods. Last answer:\n%s\n' "$output" >&2
    "$engine" exec "$node_name" grep -n admission "$manifest" >&2 || true
    "$engine" exec "$node_name" sh -c 'ls -l /var/log/pods/ | grep apiserver; tail -n 20 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log' >&2 || true
    exit 1
  fi
  sleep 5
done
printf '%s\n' "$output"
