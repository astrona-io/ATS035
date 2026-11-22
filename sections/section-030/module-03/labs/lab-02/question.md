---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Make ImagePolicyWebhook Fail Closed

Solve this question on: `terminal`

Turn on the ImagePolicyWebhook admission plugin on the kube-apiserver and make it fail closed, so that a pod is rejected when the image policy backend cannot be reached.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Starting state

The `starfleet` security team wants no new pod to start in the cluster unless their image policy backend has approved its images. The backend is not deployed yet, and until it is, new pods must be rejected.

The control plane node has the directory `/etc/kubernetes/admission` with two files. The file `admission-config.yaml` configures the ImagePolicyWebhook plugin with `defaultAllow: true`. The file `backend.kubeconfig` points the plugin to the backend `https://127.0.0.1:9443/image-review`, where no service answers. The kube-apiserver does not load the plugin yet, so every new pod is admitted. The namespace `starfleet-035-030-03-02` has the running pod `bridge`.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-03-02" || exit 1
node_name="astro-ats-035-lab-030-03-02-control-plane"
worker_name="astro-ats-035-lab-030-03-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system. The commands use Podman; with Docker, write `docker` instead of `podman`.

## Tasks

1. In `/etc/kubernetes/admission/admission-config.yaml` on the control plane node, set `defaultAllow: false`. Keep the other fields as they are.
2. In the static pod manifest `/etc/kubernetes/manifests/kube-apiserver.yaml`, add `ImagePolicyWebhook` to `--enable-admission-plugins` (keep `NodeRestriction`) and add `--admission-control-config-file=/etc/kubernetes/admission/admission-config.yaml`.
3. In the same manifest, mount the node directory `/etc/kubernetes/admission` read-only at the same path in the kube-apiserver container, with a `hostPath` volume.
4. When the kube-apiserver has restarted, prove with a server-side dry run that a new pod in `starfleet-035-030-03-02` is rejected because the backend cannot be reached.

## Constraints

- Do not change `backend.kubeconfig` and do not deploy a backend.
- Keep a backup of the original manifest outside `/etc/kubernetes/manifests`. Leave no other file in that directory.
- The pod `bridge` and the pod `drifter` in `outpost-035-030-03-02` must keep running.

## How the answer is checked

The grader runs three checks. The first reads the command line of the running kube-apiserver process on the control plane node and needs both flags, and it checks that the API server is ready. The second reads the two files in `/etc/kubernetes/admission`. The third sends a server-side dry run of a new BusyBox pod and needs a `Forbidden` answer that names the backend address `127.0.0.1:9443`.
