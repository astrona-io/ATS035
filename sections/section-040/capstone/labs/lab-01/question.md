---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Release A Workload Through Analysis, A Scan Gate And Restricted Admission

Analyse an unsafe workload document, decide a scan gate, enforce restricted admission and run the corrected workload.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. Namespace `bay` holds three ConfigMaps: `analysis-source` with a workload document `workload.json` that is not deployed, `scan-results` with a scan report in Trivy JSON shape, and `scan-exceptions` with an ignore list. Namespace `bay` has no Pod Security Admission labels. Nothing is recorded or enforced yet.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-040)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-040" || exit 1
node_name="astro-ats-035-capstone-040-control-plane"
worker_name="astro-ats-035-capstone-040-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

In namespace `bay`: (1) Label the namespace with `pod-security.kubernetes.io/enforce=restricted`, `pod-security.kubernetes.io/enforce-version=v1.35`, `pod-security.kubernetes.io/warn=restricted` and `pod-security.kubernetes.io/audit=restricted`. (2) Analyse `workload.json` without deploying it and record ConfigMap `analysis-findings` with the keys `privileged` (`true`), `runAsNonRoot` (`missing`), `allowPrivilegeEscalation` (`missing`) and `imageTag` (the tag the image uses). (3) Create ConfigMap `scan-gate` from `scan-results` and `scan-exceptions`: findings with severity HIGH or CRITICAL count, findings without a fixed version are ignored, findings on the ignore list are waived. Use the keys `decision` (`fail` when any blocking finding remains, otherwise `pass`), `blocking`, `waived` and `unfixed` (sorted, comma-separated identifiers without spaces), `severity` set to `HIGH,CRITICAL` and `ignoreUnfixed` set to `true`. (4) Create pod `corrected-reader` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, the `RuntimeDefault` seccomp profile, `allowPrivilegeEscalation: false` and all capabilities dropped. It must be Ready. The original unsafe document must be rejected by the namespace, and you must not deploy it. Keep the three source ConfigMaps unchanged.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
