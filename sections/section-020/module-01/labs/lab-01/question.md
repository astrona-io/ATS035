---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Bind A Package Inventory To A Running Image

Record installed operating-system packages and the image identity actually running them.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-01-01" || exit 1
node_name="astro-ats-035-lab-020-01-01-control-plane"
worker_name="astro-ats-035-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create supply-inventory with image docker.io/library/python:3.13-alpine, runtimeImageID matching a ready probe container, packages containing the sorted actual apk info -v lines, and scope alpine-installed-packages. Preserve the original application. This is operating-system package inventory; it is not a complete software bill of materials (SBOM), signature proof or a vulnerability scan.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
