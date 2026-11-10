---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce The Restricted Pod Security Standard

Solve this question on: `terminal`

Label a namespace to enforce the restricted Pod Security Standard and run one compliant pod while an unrestricted pod is rejected.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `hangar-035-040-03-01` exists without Pod Security Admission labels, so every pod is accepted there.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-01" || exit 1
node_name="astro-ats-035-lab-040-03-01-control-plane"
worker_name="astro-ats-035-lab-040-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. Label the namespace `hangar-035-040-03-01` with `pod-security.kubernetes.io/enforce=restricted`, `pod-security.kubernetes.io/enforce-version=v1.35`, `pod-security.kubernetes.io/warn=restricted` and `pod-security.kubernetes.io/audit=restricted`.
2. Create the pod `restricted-reader` in that namespace with `restartPolicy: Never` and one container `reader` that uses `docker.io/library/busybox:1.37.0` and runs `sh -c "sleep 3600"`. Set `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000` and the `RuntimeDefault` seccomp profile at pod level, and `allowPrivilegeEscalation: false` with all capabilities dropped in the container. It must be Ready.
3. Check with a server-side dry run that a pod setting `privileged: true` is rejected in `hangar-035-040-03-01`. Do not create it.

## Constraints

- Label only the namespace `hangar-035-040-03-01`.
- Do not change the `probe` Deployment or the client pods.

## How the answer is checked

The grader runs three checks. The first reads the four namespace labels. The second reads `restricted-reader` and needs it ready. The third makes a server-side dry run of a privileged pod, which Pod Security Admission must reject, and needs no pod named `unrestricted-reader` to exist.
