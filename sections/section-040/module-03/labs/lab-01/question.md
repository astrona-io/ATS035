---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce The Restricted Pod Security Standard

Label a namespace to enforce the restricted Pod Security Standard and run one compliant pod while an unrestricted pod is rejected.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `hangar` exists without Pod Security Admission labels, so every pod is accepted there.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-01" || exit 1
node_name="astro-ats-035-lab-040-03-01-control-plane"
worker_name="astro-ats-035-lab-040-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Label namespace `hangar` with `pod-security.kubernetes.io/enforce=restricted`, `pod-security.kubernetes.io/enforce-version=v1.35`, `pod-security.kubernetes.io/warn=restricted` and `pod-security.kubernetes.io/audit=restricted`. Create pod `restricted-reader` in `hangar` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, the `RuntimeDefault` seccomp profile, `allowPrivilegeEscalation: false` and all capabilities dropped. It must be Ready. A pod that sets `privileged: true` must be rejected in `hangar`, and you must not create it.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
