---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Make ImagePolicyWebhook Fail Closed

Turn on the ImagePolicyWebhook admission plugin on the kube-apiserver and make it fail closed, so that a pod is rejected when the image policy backend cannot be reached.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. The reference solution restarts the kube-apiserver, and afterwards the cluster rejects every new pod, so the lab needs a cluster of its own.
