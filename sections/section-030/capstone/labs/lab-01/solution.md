---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforce Approved Registries And Digests In One Policy Set Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-030)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-030" || exit 1
node_name="astro-ats-035-capstone-030-control-plane"
worker_name="astro-ats-035-capstone-030-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. Two more namespaces exist: `release-line`, which has no labels, and `supply-system`, which carries the label `training.astrona.io/supply-chain: exempt`. No admission policy exists.

Inspect the current objects before changing them:

```sh
kubectl get namespace release-line supply-system --show-labels
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

Label `release-line` with `training.astrona.io/supply-chain: enforced`. Create one ValidatingAdmissionPolicy named `supply-chain-rules` with `failurePolicy: Fail` that matches Pod creation and update and has two validations over all container, init container and ephemeral container images. The first requires the prefix `docker.io/library/` and uses the message `image registry is not approved`. The second requires an image that ends in `@sha256:` and 64 lowercase hexadecimal characters and uses the message `every image must be referenced by digest`. Create a binding named `supply-chain-rules` with the single action `Deny` for namespaces that carry the label value `enforced`. In `release-line`, a pod with the image `docker.io/library/busybox:1.37.0` and a pod with a tag-only init container must be rejected with the digest message. A pod with the image `unapproved.example/app@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` must be rejected with the registry message. A pod with the image `docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` must be accepted. In `supply-system`, the pod with the tag-only image must be accepted, and the `supply-system` label must stay unchanged. Test every case with a server-side dry run.

Save this as `supply-chain-policy-set.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: release-line
  labels:
    training.astrona.io/supply-chain: enforced
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: supply-chain-rules
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
  - expression: variables.images.all(i, i.startsWith('docker.io/library/'))
    message: image registry is not approved
  - expression: variables.images.all(i, i.matches('@sha256:[a-f0-9]{64}$'))
    message: every image must be referenced by digest
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: supply-chain-rules
spec:
  policyName: supply-chain-rules
  validationActions:
  - Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        training.astrona.io/supply-chain: enforced
```

Apply the scoped correction:

```sh
kubectl apply -f supply-chain-policy-set.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl get namespace release-line --show-labels
kubectl get validatingadmissionpolicybinding supply-chain-rules -o jsonpath='{.spec.validationActions}{"\n"}'
```

The binding needs a few seconds before it takes effect. Then test each case from the required result with `kubectl create --dry-run=server -f`, one pod at a time. A request that the policy rejects returns a nonzero status, so run it separately from a shell sequence that stops on error. The exempt namespace must accept the tag-only pod because no binding selects it. The commands deliberately target one environment. No example command output is presented as evidence of a completed run.

After recording your result, remove the independent lab with `astrona destroy ats-035-capstone-030`.

## Common pitfalls

> [!WARNING]
> The label on the namespace is what puts a namespace under the policy. Do not label `supply-system`, and do not relax the policy to make a test pass. A registry prefix and a digest rule check text, and neither verifies a signature.
