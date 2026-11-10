---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforce An Approved Image Registry

Solve this question on: `terminal`

Use a validating admission policy and binding to deny an unapproved image before scheduling.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-01-01" || exit 1
node_name="astro-ats-035-lab-030-01-01-control-plane"
worker_name="astro-ats-035-lab-030-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. Create the namespace `approved-images-035-030-01-01` with the label `training.astrona.io/registry-policy: enabled`.
2. Create the ValidatingAdmissionPolicy `training-registry` with `failurePolicy: Fail` for Pod `CREATE` and `UPDATE` (including `pods/ephemeralcontainers`). Its validations require every image in `containers`, `initContainers` and `ephemeralContainers` to start with `docker.io/library/`, each with the message `only the training approved registry prefix is allowed`.
3. Bind it with the ValidatingAdmissionPolicyBinding `training-registry`, the single validation action `Deny` and a namespace selector on that label.
4. Run the pod `approved-reader` in the namespace, with `restartPolicy: Never` and one container `reader` that uses `docker.io/library/busybox:1.37.0` and runs `sh -c "sleep 3600"`, and check that a server-side dry run of a pod with `unapproved.example/reader:v1` is rejected.

## Constraints

- Do not change anything in `starfleet-035-030-01-01` or `outpost-035-030-01-01`.
- This registry rule does not verify signatures or publisher provenance; those need separate evidence.

## How the answer is checked

The grader runs three checks. The first reads the policy and the binding. The second checks the namespace label and makes a server-side dry run of a pod with `unapproved.example/reader:v1`, which must be rejected with the policy message. The third needs `approved-reader` to be ready.

Hint: `kubectl create --dry-run=server -f pod.yaml` sends a pod through admission without creating it.
