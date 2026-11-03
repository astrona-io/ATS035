---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Give A Service Account Registry Pull Access

Create a registry pull secret, attach it to a service account and run a pod that receives it.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods and a ServiceAccount named probe-runner. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-03-01" || exit 1
node_name="astro-ats-035-lab-020-03-01-control-plane"
worker_name="astro-ats-035-lab-020-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the Secret registry-credentials of type kubernetes.io/dockerconfigjson in starfleet for the registry registry.example.test with the user builder and the password s3cret-pull-token. Add the secret to the imagePullSecrets of the existing ServiceAccount probe-runner. Run a pod named release-check with the service account probe-runner and the image docker.io/library/busybox:1.37.0 that runs sleep 3600. The pod must receive the pull secret through its service account, not through a pod-level setting. The registry host and the credential are examples; this task shows how pull access is configured and does not pull from that host.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
