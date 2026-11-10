---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Analyze And Correct A Workload Security Document

Solve this question on: `terminal`

Inspect a non-executed unsafe resource definition and run a corrected restricted workload.

Allow about 8 minutes for the tasks. Cluster startup adds time.

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

## Tasks

1. Read `workload.json` from the ConfigMap `analysis-source` in the namespace `starfleet-035-040-01-01`. Do not deploy it.
2. Create the ConfigMap `analysis-findings` in the same namespace with the keys `privileged` set to `true`, and `runAsNonRoot` and `allowPrivilegeEscalation` each set to `missing`.
3. Create the pod `analyzed-reader` with `restartPolicy: Never` and one container `reader` that uses `docker.io/library/busybox:1.37.0` and runs `sh -c "sleep 3600"`. At pod level, set `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, `fsGroup: 1000` and the `RuntimeDefault` seccomp profile. In the container, set `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and drop `ALL` capabilities. Mount an `emptyDir` volume named `scratch` at `/scratch`. The pod must be Ready.

## Constraints

- Do not change the ConfigMap `analysis-source`.
- This focused field analysis is not a full image vulnerability scan or a replacement for a named scanner.

## How the answer is checked

The grader runs two checks. The first reads the findings in `analysis-findings`. The second reads `analyzed-reader`: its container, both security contexts and the `scratch` volume, and needs it ready. Both checks need `analysis-source` to still describe the privileged workload.
