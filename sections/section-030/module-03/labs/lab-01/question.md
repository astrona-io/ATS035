---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforce A Registry Policy And Attach Pull Credentials

Change an audit-only registry binding to enforcement and attach registry pull credentials to a ServiceAccount.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `gated-images` has a ServiceAccount named `deployer`, a ValidatingAdmissionPolicy named `gated-registry` and a binding of the same name. The binding has the validation action `Audit` only, so no pod is rejected yet.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-03-01" || exit 1
node_name="astro-ats-035-lab-030-03-01-control-plane"
worker_name="astro-ats-035-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Change the binding `gated-registry` so that its only validation action is `Deny`, and leave the policy and the namespace selector as they are. In `gated-images`, create a Secret named `registry-credentials` of type `kubernetes.io/dockerconfigjson` that holds credentials for the registry `registry.example.com` with the user `reader` and the password `example-pass`. Add the Secret to the `imagePullSecrets` of the ServiceAccount `deployer`. A server-side dry run of a pod in `gated-images` that uses `unapproved.example/reader:v1` must be rejected with the policy message `image registry is not approved`. A pod that uses `docker.io/library/busybox:1.37.0` and the ServiceAccount `deployer` must be accepted, and the accepted object must list `registry-credentials` as an image pull secret. The credentials are example values for this exercise.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
