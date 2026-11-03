---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Run A Pod With A Restricted Security Context

Run a BusyBox pod as a numeric non-root user with a read-only root filesystem, no capabilities and the runtime default seccomp profile, and prove each setting from inside the container.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required pod does not exist.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-02-01" || exit 1
node_name="astro-ats-035-lab-010-02-01-control-plane"
worker_name="astro-ats-035-lab-010-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

The `drifter` pod in the `outpost` namespace must stay untouched. In the `starfleet` namespace, create a pod named `restricted-runner` with one container named `app`. The container uses `docker.io/library/busybox:1.37.0` and runs `sh -c "sleep 3600"`. The pod must have `restartPolicy: Never`.

Set these security fields. At pod level: `runAsNonRoot: true`, `runAsUser: 10001` and a `seccompProfile` of type `RuntimeDefault`. At container level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and `capabilities.drop` with the single value `ALL`. Inside the running container, the user ID must be 10001 and a write to the root filesystem must fail.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for the pod to become ready before submitting. Preserve the task's namespace, workload names and unrelated components.
