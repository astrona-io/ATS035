---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Starting Environment

The control plane node has the directory `/etc/kubernetes/admission` with two files. The file `admission-config.yaml` configures the ImagePolicyWebhook plugin with `defaultAllow: true`. The file `backend.kubeconfig` points the plugin to the backend `https://127.0.0.1:9443/image-review`, where no service answers. The kube-apiserver does not load the plugin yet, so every new pod is admitted. The namespace `starfleet-035-030-03-02` has the running pod `bridge`.

Turn on the ImagePolicyWebhook admission plugin on the kube-apiserver and make it fail closed, so that a pod is rejected when the image policy backend cannot be reached.
