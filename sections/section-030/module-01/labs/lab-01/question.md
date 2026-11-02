---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforce An Approved Image Registry

Use a validating admission policy and binding to deny an unapproved image before scheduling.

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

## Required result

Create approved-images namespace with the policy selector label. Install training-registry ValidatingAdmissionPolicy and its Deny binding. Restrict ordinary, init and ephemeral Pod container images to docker.io/library/ in that namespace. Keep approved-reader Ready and reject a server-side dry-run unapproved.example image with the policy message. This registry rule does not verify signatures or publisher provenance; those need separate evidence.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
