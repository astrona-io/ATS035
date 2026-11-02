---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Analyze And Correct A Workload Security Document

Inspect a non-executed unsafe resource definition and run a corrected restricted workload.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-01-01" || exit 1
node_name="astro-ats-035-lab-040-01-01-control-plane"
worker_name="astro-ats-035-lab-040-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Analyze workload.json from ConfigMap analysis-source without deploying it. Record the privileged true and missing runAsNonRoot and allowPrivilegeEscalation findings in analysis-findings. Create analyzed-reader with the supplied non-root, no-privilege-escalation, dropped-capability, RuntimeDefault and read-only-root settings. It must be Ready. This focused field analysis is not a full image vulnerability scan or a replacement for a named scanner.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
