---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Combine Registry And Digest Rules In One Admission Policy Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-02-02" || exit 1
```

Keep this connection selected. Every command in this lab talks to the API server of this cluster only.

## Inspect the starting state

The binding selects namespaces by label, so read the labels and the pods first:

```sh
kubectl get namespace starfleet-035-030-02-02 outpost-035-030-02-02 --show-labels
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
kubectl -n starfleet-035-030-02-02 get pods -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[*].image'
```

The `outpost-035-030-02-02` namespace has the label value `exempt`, and the `starfleet-035-030-02-02` namespace has no `training.astrona.io/release-gate` label yet. No policy exists. The pod `legacy-scout` uses a tag-only image from Docker Hub, so it breaks both rules that you are about to write.

## Label the namespace

Save this as `namespace-starfleet.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: starfleet-035-030-02-02
  labels:
    project: starfleet-035-030-02-02
    training.astrona.io/release-gate: enforced
```

Apply it:

```sh
kubectl apply -f namespace-starfleet.yaml
```

## Write the policy with two validations

The policy runs inside the API server. A variable collects the images of all three container lists, so each validation is written once. Each validation has its own message, so an author whose pod is rejected learns which rule the pod broke. The registry rule ends in `/` so that a lookalike host such as `registry.starfleet.test.example.com` does not pass.

Save this as `validatingadmissionpolicy-release-gate.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: release-gate
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image) +
      (has(object.spec.initContainers) ? object.spec.initContainers.map(c, c.image) : []) +
      (has(object.spec.ephemeralContainers) ? object.spec.ephemeralContainers.map(c, c.image) : [])
  validations:
  - expression: "variables.images.all(i, i.startsWith('registry.starfleet.test/'))"
    message: "image must come from registry.starfleet.test"
  - expression: "variables.images.all(i, i.matches('@sha256:[a-f0-9]{64}$'))"
    message: "image must be referenced by digest"
```

Apply it:

```sh
kubectl apply -f validatingadmissionpolicy-release-gate.yaml
```

Then check that the API server type-checked the expressions. An empty result means that it found no problem:

```sh
kubectl get validatingadmissionpolicy release-gate -o jsonpath='{.status.typeChecking}{"\n"}'
```

## Bind the policy to the enforced namespace

The policy does nothing until a binding selects requests for it. The binding below uses `Deny` and selects only namespaces with the value `enforced`. The `outpost-035-030-02-02` namespace has the value `exempt`, so the binding does not select it.

Save this as `validatingadmissionpolicybinding-release-gate.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: release-gate
spec:
  policyName: release-gate
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        training.astrona.io/release-gate: enforced
```

Apply it:

```sh
kubectl apply -f validatingadmissionpolicybinding-release-gate.yaml
```

## Test each rule on its own

Wait a few seconds for the binding to take effect. Then send pods that each break one rule through admission with a server-side dry run. The API server runs the whole admission chain and stores nothing, and it does not pull the image, so the made-up digest of 64 letters `a` is enough. Save this as `pod-other-registry.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: other-registry
  namespace: starfleet-035-030-02-02
spec:
  containers:
  - name: app
    image: docker.io/library/busybox@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

Save this as `pod-tag-only.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tag-only
  namespace: starfleet-035-030-02-02
spec:
  containers:
  - name: app
    image: registry.starfleet.test/scout:1.0
```

Save this as `pod-compliant.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: compliant
  namespace: starfleet-035-030-02-02
spec:
  containers:
  - name: app
    image: registry.starfleet.test/scout@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

Send all three through admission:

```sh
kubectl apply --dry-run=server -f pod-other-registry.yaml
kubectl apply --dry-run=server -f pod-tag-only.yaml
kubectl apply --dry-run=server -f pod-compliant.yaml
```

The first request fails with an error that names the policy `release-gate` and the registry message. The second fails with the digest message. The third is accepted. The same tag-only pod in `outpost-035-030-02-02` is still accepted, because the binding does not select that namespace.

## Remove the pod that admission never checked

Admission runs when a pod is created or updated. The pod `legacy-scout` was created before the policy existed, so it keeps running even though it breaks both rules. List the images in the namespace again, and delete every pod that breaks a rule:

```sh
kubectl -n starfleet-035-030-02-02 get pods -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[*].image'
kubectl -n starfleet-035-030-02-02 delete pod legacy-scout
```

A real workload would be rebuilt with a pinned image from the approved registry and deployed again, and the policy would check that new pod.

After recording your result, remove the lab with `astrona destroy ats-035-lab-030-02-02`.

## Common pitfalls

> [!WARNING]
> - Writing both rules in one expression with one message. The author then cannot tell which rule the pod broke.
> - Leaving out the `/` after the registry host. A lookalike host such as `registry.starfleet.test.example.com` then passes.
> - Changing the label of the exempt namespace to make a test pass. One label value switches the control on or off for the whole namespace.
> - Expecting the policy to remove running pods. Admission checks only new requests, so audit what already runs.
