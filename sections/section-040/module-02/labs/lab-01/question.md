---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Decide A Scan Gate From Scan Results

Compute a release gate decision from supplied Trivy-style scan results and record it.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The ConfigMap `scan-results` in `starfleet` holds a scan report in Trivy JSON shape, and the ConfigMap `scan-exceptions` holds an ignore list. No gate decision has been recorded.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-02-01" || exit 1
node_name="astro-ats-035-lab-040-02-01-control-plane"
worker_name="astro-ats-035-lab-040-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Read `results.json` from ConfigMap `scan-results` and the ignore list `trivyignore.txt` from ConfigMap `scan-exceptions` in `starfleet`. The gate looks only at findings with severity HIGH or CRITICAL and ignores findings that have no fixed version. A finding on the ignore list is waived. Create ConfigMap `scan-gate` in `starfleet` with these keys: `decision` (`fail` when any blocking finding remains, otherwise `pass`), `blocking`, `waived` and `unfixed` (each a sorted, comma-separated list of finding identifiers without spaces), `severity` set to `HIGH,CRITICAL` and `ignoreUnfixed` set to `true`. Do not change the report or the ignore list. The report is test data, and a gate decision is not proof that an image is safe.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
