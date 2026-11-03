---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Guided Practice: Enforce A Registry Policy And Attach Pull Credentials

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-030-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-030-03" || exit 1
node_name="astro-ats-035-playground-030-03-control-plane"
worker_name="astro-ats-035-playground-030-03-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `gated-images` has a ServiceAccount named `deployer`, a ValidatingAdmissionPolicy named `gated-registry` and a binding of the same name. The binding has the validation action `Audit` only, so no pod is rejected yet.

Inspect the current objects before changing them:

```sh
kubectl -n gated-images get serviceaccount deployer -o yaml
kubectl get validatingadmissionpolicybinding gated-registry -o yaml
```

Change the binding `gated-registry` so that its only validation action is `Deny`, and leave the policy and the namespace selector as they are. In `gated-images`, create a Secret named `registry-credentials` of type `kubernetes.io/dockerconfigjson` that holds credentials for the registry `registry.example.com` with the user `reader` and the password `example-pass`. Add the Secret to the `imagePullSecrets` of the ServiceAccount `deployer`. A server-side dry run of a pod in `gated-images` that uses `unapproved.example/reader:v1` must be rejected with the policy message `image registry is not approved`. A pod that uses `docker.io/library/busybox:1.37.0` and the ServiceAccount `deployer` must be accepted, and the accepted object must list `registry-credentials` as an image pull secret. The credentials are example values for this exercise.

Save this as `binding-and-pull-secret.yaml`:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: gated-registry
spec:
  policyName: gated-registry
  validationActions:
  - Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        training.astrona.io/gated: enabled
---
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: gated-images
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{"auths":{"registry.example.com":{"username":"reader","password":"example-pass","auth":"cmVhZGVyOmV4YW1wbGUtcGFzcw=="}}}'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployer
  namespace: gated-images
imagePullSecrets:
- name: registry-credentials
```

Apply the scoped correction:

```sh
kubectl apply -f binding-and-pull-secret.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl get validatingadmissionpolicybinding gated-registry -o jsonpath='{.spec.validationActions}{"\n"}'
kubectl -n gated-images get serviceaccount deployer -o jsonpath='{.imagePullSecrets}{"\n"}'
kubectl -n gated-images get secret registry-credentials -o jsonpath='{.type}{"\n"}'
```

The binding needs a few seconds before it takes effect. Then send a pod with the image `unapproved.example/reader:v1` through `kubectl create --dry-run=server`; it must fail with the policy message. Send a pod with the image `docker.io/library/busybox:1.37.0` and `serviceAccountName: deployer` with `-o json`; the accepted object lists `registry-credentials` under `imagePullSecrets`, which the ServiceAccount admission plugin copies from the ServiceAccount. The commands deliberately target one environment. No example command output is presented as evidence of a completed run.


## Common pitfalls

> [!WARNING]
> A binding with only `Audit` never rejects a request. An image pull secret is base64 encoded and not encrypted by that encoding, so use example values in training and protect real credentials with RBAC.
