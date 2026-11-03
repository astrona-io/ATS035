---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Require Image Digests In A Namespace

Deny a pod whose image is not referenced by digest and admit a pod whose image is.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-02-01" || exit 1
node_name="astro-ats-035-lab-030-02-01-control-plane"
worker_name="astro-ats-035-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the namespace `pinned-images` with the label `training.astrona.io/digest-policy: enabled`. Install a ValidatingAdmissionPolicy named `require-digest` with `failurePolicy: Fail` that matches Pod creation and update, and a ValidatingAdmissionPolicyBinding named `require-digest` with the single validation action `Deny`, scoped to namespaces that carry the label. The policy must require that every image in `containers`, `initContainers` and `ephemeralContainers` ends in `@sha256:` followed by 64 lowercase hexadecimal characters, and its message must contain `must be referenced by digest`. A server-side dry run of a pod in `pinned-images` that uses `docker.io/library/busybox:1.37.0` must be rejected, and so must a pod that has a tag-only init container. A server-side dry run of a pod that uses `docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` must be accepted. The same tag-only pod in `starfleet` must still be accepted. The dry runs only test admission, so the digest in the accepted pod does not need to exist in a registry.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
