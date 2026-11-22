---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Make ImagePolicyWebhook Fail Closed Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-03-02" || exit 1
node_name="astro-ats-035-lab-030-03-02-control-plane"
worker_name="astro-ats-035-lab-030-03-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system. The commands use Podman; with Docker, write `docker` instead of `podman`.

## Inspect the starting state

The ImagePolicyWebhook plugin runs inside the kube-apiserver, so its settings live in files on the control plane node and in the flags of the API server. Read both before you change anything:

```sh
podman exec "$node_name" grep -n admission /etc/kubernetes/manifests/kube-apiserver.yaml
podman exec "$node_name" cat /etc/kubernetes/admission/admission-config.yaml
podman exec "$node_name" cat /etc/kubernetes/admission/backend.kubeconfig
```

The first command shows only the line `- --enable-admission-plugins=NodeRestriction`, so the API server does not load ImagePolicyWebhook. The second shows the plugin configuration with `defaultAllow: true`. The third shows the backend address `https://127.0.0.1:9443/image-review`. Nothing listens on that port on the node. Even with the plugin on, `defaultAllow: true` would admit every pod while the backend is down, which is the fail-open setting.

A server-side dry run sends a request through authentication, authorization and every admission plugin, but the API server does not store the object. Use it to see that a new pod is admitted now:

```sh
kubectl -n starfleet-035-030-03-02 run image-check --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server
```

The command succeeds. It reports the pod `image-check` as created and marks the answer as a server dry run, so no pod was stored.

## Make the plugin fail closed

The plugin reads its configuration file only when the API server starts, so change the file first. Save this as `admission-config.yaml`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/admission/backend.kubeconfig
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
```

Copy it to the node. The command sends the file through standard input into the node container:

```sh
podman exec -i "$node_name" sh -c 'cat > /etc/kubernetes/admission/admission-config.yaml' < admission-config.yaml
podman exec "$node_name" grep defaultAllow /etc/kubernetes/admission/admission-config.yaml
```

The second command prints `defaultAllow: false`.

## Change the API server manifest

The kubelet on the control plane node watches `/etc/kubernetes/manifests` and restarts a static pod as soon as its file changes. Keep a backup outside that directory, because the kubelet would try to run a second API server from a copy inside it. Copy the manifest to your host shell to edit it:

```sh
podman exec "$node_name" cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/kube-apiserver.yaml.backup
podman cp "$node_name":/etc/kubernetes/manifests/kube-apiserver.yaml kube-apiserver.yaml
```

Open `kube-apiserver.yaml` in an editor and make three changes. Keep the indentation of the lines around each change. First, in the `command` list of the container, replace the plugin line and add the configuration flag under it:

```yaml
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
    - --admission-control-config-file=/etc/kubernetes/admission/admission-config.yaml
```

Second, add this item to the container's `volumeMounts` list:

```yaml
    - mountPath: /etc/kubernetes/admission
      name: image-policy
      readOnly: true
```

Third, add this item to the pod's `volumes` list:

```yaml
  - hostPath:
      path: /etc/kubernetes/admission
      type: DirectoryOrCreate
    name: image-policy
```

Without the volume, the API server container cannot see the node directory, and the API server stops at startup because it cannot read the file that the flag names. Copy the file back in one step:

```sh
podman cp kube-apiserver.yaml "$node_name":/etc/kubernetes/manifests/kube-apiserver.yaml
```

The kubelet now stops the old API server and starts a new one. For some seconds `kubectl` gets no answer. Wait until it answers again:

```sh
until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
```

If the API server does not come back within about two minutes, the manifest or a file has a mistake. Read the newest API server log on the node with `podman exec "$node_name" sh -c 'tail -n 20 /var/log/pods/kube-system_kube-apiserver-*/kube-apiserver/*.log'`, fix the file, or copy the backup back into place.

## Verify the result

Send the same dry run again:

```sh
kubectl -n starfleet-035-030-03-02 run image-check --image=docker.io/library/busybox:1.37.0 --restart=Never --dry-run=server
```

The request now fails with a `Forbidden` error. The message names the `Post` request to `https://127.0.0.1:9443/image-review` and the network error from the failed connection. The ImagePolicyWebhook plugin in the kube-apiserver sent an `ImageReview` to the backend, got no answer, and with `defaultAllow: false` rejected the pod. If the dry run still succeeds, the old API server may still be running; wait a few seconds and send it again.

Check that the running process uses both flags, and that the existing pods still run:

```sh
podman exec "$node_name" sh -c 'cat /proc/[0-9]*/cmdline 2>/dev/null | tr "\000" "\n" | grep -E "enable-admission-plugins|admission-control-config-file"'
kubectl get pod bridge -n starfleet-035-030-03-02
kubectl get pod drifter -n outpost-035-030-03-02
```

The first command prints the two flags with the values you set. Both pods are still `Running`, because admission checks only new requests and does not stop pods that already run. The same rule also blocks every other new pod in the cluster until a backend answers, so a real cluster needs the backend running with several replicas before it turns on `defaultAllow: false`.

After recording your result, remove the lab with `astrona destroy ats-035-lab-030-03-02`.

## Common pitfalls

> [!WARNING]
> - Changing only `defaultAllow` in the file. The API server reads the file at startup, so a change takes effect only after the static pod restarts.
> - Adding the flags without the `hostPath` volume and its mount. The API server cannot read the file and does not start.
> - Leaving a backup copy such as `kube-apiserver.yaml.bak` in `/etc/kubernetes/manifests`. The kubelet runs every manifest in that directory.
> - Removing `NodeRestriction` while you edit the plugin list. Add the new plugin to the list.
> - Testing with `kubectl auth can-i`. Admission plugins do not run for it; send a real request with `--dry-run=server`.
