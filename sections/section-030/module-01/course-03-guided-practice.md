---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Guided Practice: Enforce An Approved Image Registry

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-030-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-030-01" || exit 1
node_name="astro-ats-035-playground-030-01-control-plane"
worker_name="astro-ats-035-playground-030-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create approved-images namespace with the policy selector label. Install training-registry ValidatingAdmissionPolicy and its Deny binding. Restrict ordinary, init and ephemeral Pod container images to docker.io/library/ in that namespace. Keep approved-reader Ready and reject a server-side dry-run unapproved.example image with the policy message. This registry rule does not verify signatures or publisher provenance; those need separate evidence.

Save this as `namespace-approved-images.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: approved-images
  labels:
    training.astrona.io/registry-policy: enabled
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: training-registry
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
      - pods/ephemeralcontainers
  validations:
  - expression: object.spec.containers.all(c, c.image.startsWith('docker.io/library/'))
    message: only the training approved registry prefix is allowed
  - expression: '!has(object.spec.initContainers) || object.spec.initContainers.all(c,
      c.image.startsWith(''docker.io/library/''))'
    message: only the training approved registry prefix is allowed
  - expression: '!has(object.spec.ephemeralContainers) || object.spec.ephemeralContainers.all(c,
      c.image.startsWith(''docker.io/library/''))'
    message: only the training approved registry prefix is allowed
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: training-registry
spec:
  policyName: training-registry
  validationActions:
  - Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        training.astrona.io/registry-policy: enabled
---
apiVersion: v1
kind: Pod
metadata:
  name: approved-reader
  namespace: approved-images
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply the scoped correction:

```sh
kubectl apply -f namespace-approved-images.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n approved-images wait --for=condition=Ready pod/approved-reader --timeout=180s
python3 -c 'import json,subprocess; obj={'"'"'apiVersion'"'"': '"'"'v1'"'"', '"'"'kind'"'"': '"'"'Pod'"'"', '"'"'metadata'"'"': {'"'"'name'"'"': '"'"'blocked-reader'"'"', '"'"'namespace'"'"': '"'"'approved-images'"'"'}, '"'"'spec'"'"': {'"'"'restartPolicy'"'"': '"'"'Never'"'"', '"'"'containers'"'"': [{'"'"'name'"'"': '"'"'reader'"'"', '"'"'image'"'"': '"'"'unapproved.example/reader:v1'"'"', '"'"'command'"'"': ['"'"'sh'"'"', '"'"'-c'"'"', '"'"'sleep 3600'"'"']}]}}; result=subprocess.run(['"'"'kubectl'"'"','"'"'create'"'"','"'"'--dry-run=server'"'"','"'"'-f'"'"','"'"'-'"'"'],input=json.dumps(obj),capture_output=True,text=True,timeout=15); assert result.returncode!=0 and '"'"'only the training approved registry prefix'"'"' in result.stderr; print('"'"'unapproved-image-denied'"'"')'
```

Use a validating admission policy and binding to deny an unapproved image before scheduling. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.


## Common pitfalls

> [!WARNING]
> A policy needs a binding with Deny to enforce rejection. Scope it to the selected namespace. A registry prefix alone does not authenticate an image or verify its signature.
