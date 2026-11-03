---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Require Image Digests In A Namespace Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-02-01" || exit 1
node_name="astro-ats-035-lab-030-02-01-control-plane"
worker_name="astro-ats-035-lab-030-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get namespace pinned-images
```

Create the namespace `pinned-images` with the label `training.astrona.io/digest-policy: enabled`. Install a ValidatingAdmissionPolicy named `require-digest` with `failurePolicy: Fail` that matches Pod creation and update, and a ValidatingAdmissionPolicyBinding named `require-digest` with the single validation action `Deny`, scoped to namespaces that carry the label. The policy must require that every image in `containers`, `initContainers` and `ephemeralContainers` ends in `@sha256:` followed by 64 lowercase hexadecimal characters, and its message must contain `must be referenced by digest`. A server-side dry run of a pod in `pinned-images` that uses `docker.io/library/busybox:1.37.0` must be rejected, and so must a pod that has a tag-only init container. A server-side dry run of a pod that uses `docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` must be accepted. The same tag-only pod in `starfleet` must still be accepted. The dry runs only test admission, so the digest in the accepted pod does not need to exist in a registry.

Save this as `namespace-pinned-images.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: pinned-images
  labels:
    training.astrona.io/digest-policy: enabled
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-digest
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups:
      - ''
      apiVersions:
      - v1
      operations:
      - CREATE
      - UPDATE
      resources:
      - pods
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image) +
      (has(object.spec.initContainers) ? object.spec.initContainers.map(c, c.image) : []) +
      (has(object.spec.ephemeralContainers) ? object.spec.ephemeralContainers.map(c, c.image) : [])
  validations:
  - expression: variables.images.all(i, i.matches('@sha256:[a-f0-9]{64}$'))
    message: every image must be referenced by digest
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-digest
spec:
  policyName: require-digest
  validationActions:
  - Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        training.astrona.io/digest-policy: enabled
```

Apply the scoped correction:

```sh
kubectl apply -f namespace-pinned-images.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl get validatingadmissionpolicy require-digest -o jsonpath='{.status.typeChecking}{"\n"}'
kubectl get validatingadmissionpolicybinding require-digest -o jsonpath='{.spec.validationActions}{"\n"}'
```

The policy needs a few seconds before it takes effect. Then send three pods through admission with `kubectl create --dry-run=server -f`. A pod with the image `docker.io/library/busybox:1.37.0` in `pinned-images` must fail with the policy message. A pod with the image `docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` must be accepted. The first pod must be accepted in the `starfleet` namespace, because the binding selects only labelled namespaces. The commands deliberately target one environment. No example command output is presented as evidence of a completed run. A matching field alone does not establish that the API server enforces it.

After recording your result, remove the independent lab with `astrona destroy ats-035-lab-030-02-01`.

## Common pitfalls

> [!WARNING]
> A policy needs a binding with `Deny` to reject a request, and the binding needs a namespace label that matches. A digest rule checks the form of the reference and does not check a signature or that the digest exists in a registry.
