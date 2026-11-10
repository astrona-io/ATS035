---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Run A Pod With A Restricted Security Context

Solve this question on: `terminal`

Run a BusyBox pod as a numeric non-root user with a read-only root filesystem, no capabilities and the runtime default seccomp profile, and prove each setting from inside the container.

Allow about 6 minutes for the tasks. Cluster startup adds time.

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

## Tasks

1. In the namespace `starfleet-035-010-02-01`, create the pod `restricted-runner` with `restartPolicy: Never` and one container named `app`. It uses `docker.io/library/busybox:1.37.0` and runs `sh -c "sleep 3600"`.
2. At pod level, set `runAsNonRoot: true`, `runAsUser: 10001` and a `seccompProfile` of type `RuntimeDefault`.
3. At container level, set `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and `capabilities.drop` with the single value `ALL`.
4. Prove the settings from inside the running container: `id -u` prints `10001`, and a write to `/` fails.

## Constraints

- The `drifter` pod in the namespace `outpost-035-010-02-01` must stay untouched.
- Do not change the `probe` Deployment or the `shuttle` pod.

## How the answer is checked

The grader runs three checks. The first reads the pod-level security context of `restricted-runner`. The second reads its container: name, image and the container security context. The third runs commands in the ready pod: the user ID must be `10001` and `touch /should-fail` must fail.
