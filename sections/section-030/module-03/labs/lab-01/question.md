---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforce A Registry Policy And Attach Pull Credentials

Solve this question on: `terminal`

Change an audit-only registry binding to enforcement and attach registry pull credentials to a ServiceAccount.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `gated-images-035-030-03-01` has a ServiceAccount named `deployer`, a ValidatingAdmissionPolicy named `gated-registry` and a binding of the same name. The binding has the validation action `Audit` only, so no pod is rejected yet.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-03-01" || exit 1
node_name="astro-ats-035-lab-030-03-01-control-plane"
worker_name="astro-ats-035-lab-030-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. Change the binding `gated-registry` so that its only validation action is `Deny`. Leave the policy and the namespace selector as they are.
2. In the namespace `gated-images-035-030-03-01`, create the Secret `registry-credentials` of type `kubernetes.io/dockerconfigjson` for the registry `registry.example.com` with the user `reader` and the password `example-pass`.
3. Add the Secret to the `imagePullSecrets` of the ServiceAccount `deployer`.
4. Check with server-side dry runs: a pod with `unapproved.example/reader:v1` is rejected with the message `image registry is not approved`, and a pod with `docker.io/library/busybox:1.37.0` and the ServiceAccount `deployer` is accepted with `registry-credentials` as an image pull secret.

## Constraints

- Do not change the policy `gated-registry` or the namespace labels.
- The credentials are example values for this exercise.

## How the answer is checked

The grader runs three checks. The first reads the binding and needs a dry run of an `unapproved.example` pod to be rejected with the policy message. The second decodes the Secret. The third reads the ServiceAccount and needs a dry run of a pod that uses it to be accepted with `registry-credentials` as its image pull secret.
