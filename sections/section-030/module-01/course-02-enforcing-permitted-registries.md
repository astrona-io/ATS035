---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforcing Permitted Registries

A cluster that pulls from any registry can run an image that someone pushed to a public repository an hour ago. A permitted-registries rule narrows that to a short list that the organisation controls. The rule is easy to write and easy to get wrong in small ways: a prefix without a trailing slash, an init container that nobody checked, a Deployment that the policy does not match. This part writes the rule, runs it in warning mode, enforces it and then finds the places where it does not apply.

## What the rule checks

A container image reference has the form `[registry/]repository[:tag][@digest]`. The pod specification stores the string exactly as the author wrote it. If the author writes `busybox:1.37.0`, the container runtime expands it to `docker.io/library/busybox:1.37.0`, but the API server does not. A policy that tests the string in the API object therefore sees the short form. The safe rule is to require the full registry host and path in the manifest, and to compare the start of the string with a prefix that ends in `/`.

A pod has up to three lists of containers: `containers`, `initContainers` and `ephemeralContainers`. A policy that checks only `containers` leaves two ways to run an unapproved image.

## Write the policy in warning mode

The policy below collects all image strings in a variable and requires every one to start with an allowed prefix. It applies to namespaces that carry the label `training.astrona.io/demo-registry: enabled`. Select the playground cluster first:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-030-01" || exit 1
```

Save this as `registry-demo-policy.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: registry-demo
  labels:
    training.astrona.io/demo-registry: enabled
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: demo-registry
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  variables:
    - name: allowedPrefixes
      expression: "['docker.io/library/', 'registry.k8s.io/']"
    - name: images
      expression: >-
        object.spec.containers.map(c, c.image) +
        (has(object.spec.initContainers) ? object.spec.initContainers.map(c, c.image) : []) +
        (has(object.spec.ephemeralContainers) ? object.spec.ephemeralContainers.map(c, c.image) : [])
  validations:
    - expression: "variables.images.all(i, variables.allowedPrefixes.exists(p, i.startsWith(p)))"
      message: "every image must start with docker.io/library/ or registry.k8s.io/"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: demo-registry
spec:
  policyName: demo-registry
  validationActions: ["Warn", "Audit"]
  matchResources:
    namespaceSelector:
      matchLabels:
        training.astrona.io/demo-registry: enabled
```

Apply it:

```sh
kubectl apply -f registry-demo-policy.yaml
```

Then check the result. The API server compiles the CEL expressions and type-checks them in the background, and it records errors in the policy status. Wait a few seconds and read the status:

```sh
kubectl get validatingadmissionpolicy demo-registry -o jsonpath='{.status.typeChecking}{"\n"}'
```

An empty result or an empty `expressionWarnings` list means the expressions type-check. A non-empty list names the expression and the problem. The binding needs a short time after creation before it takes effect.

## Test with a server-side dry run

A dry run sends the request through the whole admission chain and does not store the object, so it is a safe way to test a policy. Save two pods. First `pod-good-registry.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: good-registry
  namespace: registry-demo
spec:
  containers:
    - name: app
      image: docker.io/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
```

And `pod-bad-registry.yaml`, which has an init container from a host that is not on the list and an approved main container:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-registry
  namespace: registry-demo
spec:
  initContainers:
    - name: prepare
      image: unapproved.example/tools/prepare:1.0
      command: ["sh", "-c", "true"]
  containers:
    - name: app
      image: docker.io/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
```

Send both through admission:

```sh
kubectl apply --dry-run=server -f pod-good-registry.yaml
kubectl apply --dry-run=server -f pod-bad-registry.yaml
```

The first request prints that the pod was created in dry-run mode. The second prints the same, plus a `Warning:` line that contains the policy message, because the binding only has `Warn` and `Audit`. The API server accepted the pod and told the client about the violation. This mode lets you see what a rule would block, for example in existing manifests, before it can break a deployment. Note that the init container is the one that violates the rule: a policy that checked only `containers` would not warn.

## Switch to Deny

When the warnings show only the violations you expect, change the action. A patch is enough:

```sh
kubectl patch validatingadmissionpolicybinding demo-registry --type=json -p '[{"op":"replace","path":"/spec/validationActions","value":["Deny"]}]'
```

Wait a few seconds, then repeat the second dry run:

```sh
kubectl apply --dry-run=server -f pod-bad-registry.yaml
```

The request now fails with an error from the API server. The error names the policy `demo-registry`, the binding and the message that you wrote. The component that made the decision is the API server, before the pod reached etcd or any node, so no node pulled anything.

## Where the rule does not apply

The rule matches the `pods` resource. Create a Deployment in the same namespace whose container uses an unapproved registry. Save this as `deployment-bad-registry.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bad-deploy
  namespace: registry-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bad-deploy
  template:
    metadata:
      labels:
        app: bad-deploy
    spec:
      containers:
        - name: app
          image: unapproved.example/tools/app:1.0
          command: ["sh", "-c", "sleep 3600"]
```

Apply it and look at the result:

```sh
kubectl apply -f deployment-bad-registry.yaml
kubectl -n registry-demo get deployment bad-deploy
kubectl -n registry-demo get events --field-selector reason=FailedCreate
```

The `apply` succeeds, because the Deployment object is not a pod. The Deployment shows zero ready replicas. The ReplicaSet controller (a component of kube-controller-manager) tries to create the pod, the API server denies it, and the event `FailedCreate` carries the policy message. The users see a healthy `apply` and a Deployment that never starts. For this reason a registry policy must match `pods`, and you check the events of the ReplicaSet when a rollout stalls. Clean up the demo objects:

```sh
kubectl delete -f deployment-bad-registry.yaml
kubectl delete -f registry-demo-policy.yaml
```

This part showed how to write, test and enforce a permitted-registries rule, and where it leaves a gap: a registry name does not tell you who pushed the image or whether the content changed. The registry rule restricts where an image comes from, not what the image is. The next part compares the built-in policy with policy engines and webhooks.

## Common pitfalls

> [!WARNING]
> - **Writing the prefix without a trailing slash.** `docker.io/lib` also matches `docker.io/library-evil/app`. End the prefix with `/`.
> - **Checking only `containers`.** Init containers and ephemeral containers run code too.
> - **Allowing short names.** `busybox:1.37.0` does not start with `docker.io/library/`, so it is denied. That is correct for the rule; require full names in manifests.
> - **Expecting a Deployment to be rejected.** The Deployment is admitted and its pods are denied. Read the events.
> - **Going straight to `Deny`.** Start with `Warn` and `Audit`, read what would break and then enforce.
