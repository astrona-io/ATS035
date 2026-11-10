---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Require Image Digests In A Namespace

Solve this question on: `terminal`

Deny a pod whose image is not referenced by digest and admit a pod whose image is.

Allow about 8 minutes for the tasks. Cluster startup adds time.

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

## Tasks

1. Create the namespace `pinned-images-035-030-02-01` with the label `training.astrona.io/digest-policy: enabled`.
2. Create the ValidatingAdmissionPolicy `require-digest` with `failurePolicy: Fail` for Pod creation and update. It requires every image in `containers`, `initContainers` and `ephemeralContainers` to end in `@sha256:` followed by 64 lowercase hexadecimal characters, and its message contains `must be referenced by digest`.
3. Bind it with the ValidatingAdmissionPolicyBinding `require-digest`, the single validation action `Deny` and a namespace selector on that label.
4. Prove it with server-side dry runs in `pinned-images-035-030-02-01`: a pod with `docker.io/library/busybox:1.37.0` is rejected, a pod with a tag-only init container is rejected, and a pod with `docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` is accepted.

## Constraints

- The same tag-only pod in `starfleet-035-030-02-01` must still be accepted.
- The dry runs only test admission, so the digest in the accepted pod does not need to exist in a registry.

## How the answer is checked

The grader runs three checks. The first reads the policy and the binding. The second checks the namespace label and needs server-side dry runs of a tag-only container and a tag-only init container to be rejected with the policy message. The third needs a dry run of a pod pinned by digest to be accepted. In every check, a tag-only pod in `starfleet-035-030-02-01` must still be accepted.
