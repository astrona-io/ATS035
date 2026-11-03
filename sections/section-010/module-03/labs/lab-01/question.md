---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Pin An Image To The Digest The Node Reports

Read the digest that the node reports for the BusyBox image and start a pod that refers to the image by that digest.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The `shuttle` pod runs `docker.io/library/busybox:1.37.0` by tag. The required pod does not exist.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-01" || exit 1
node_name="astro-ats-035-lab-010-03-01-control-plane"
worker_name="astro-ats-035-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Read the image digest from the status of the `shuttle` pod in the `starfleet` namespace. Create a pod named `pinned-runner` in the same namespace with one container named `app`. The container image must be `docker.io/library/busybox@sha256:` followed by that digest, with no tag. Set `imagePullPolicy: IfNotPresent`, `restartPolicy: Never` and the command `sh -c "sleep 3600"`. The pod must reach the Ready state, and its status must report the same digest. Leave the `shuttle` pod unchanged.

## Verify The Result

The grader reads the digest from the `shuttle` pod and compares it with the image of `pinned-runner`. Wait for the pod to become ready before submitting. Preserve the task's namespace, workload names and unrelated components.
