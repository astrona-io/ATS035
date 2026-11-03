---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforce Approved Registries And Digests In One Policy Set

Enforce an approved registry and a digest requirement together in one namespace while one system namespace stays exempt.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. Two more namespaces exist: `release-line`, which has no labels, and `supply-system`, which carries the label `training.astrona.io/supply-chain: exempt`. No admission policy exists.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-030)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-030" || exit 1
node_name="astro-ats-035-capstone-030-control-plane"
worker_name="astro-ats-035-capstone-030-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Label `release-line` with `training.astrona.io/supply-chain: enforced`. Create one ValidatingAdmissionPolicy named `supply-chain-rules` with `failurePolicy: Fail` that matches Pod creation and update and has two validations over all container, init container and ephemeral container images. The first requires the prefix `docker.io/library/` and uses the message `image registry is not approved`. The second requires an image that ends in `@sha256:` and 64 lowercase hexadecimal characters and uses the message `every image must be referenced by digest`. Create a binding named `supply-chain-rules` with the single action `Deny` for namespaces that carry the label value `enforced`. In `release-line`, a pod with the image `docker.io/library/busybox:1.37.0` and a pod with a tag-only init container must be rejected with the digest message. A pod with the image `unapproved.example/app@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` must be rejected with the registry message. A pod with the image `docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` must be accepted. In `supply-system`, the pod with the tag-only image must be accepted, and the `supply-system` label must stay unchanged. Test every case with a server-side dry run.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
