---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Serve Content With A Minimal Runtime

Select an image providing only the required HTTP process and verify its running contents.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-01-01" || exit 1
node_name="astro-ats-035-lab-010-01-01-control-plane"
worker_name="astro-ats-035-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create minimal-content with index.html containing minimal-version=v1. Run minimal-server using BusyBox 1.37.0 and its httpd process on port 8080 with a read-only content mount. The client must receive the page and the container must not contain a Python interpreter. Image size alone is not a vulnerability assessment.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
