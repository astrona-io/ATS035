---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Decide A Scan Gate From Scan Results

Solve this question on: `terminal`

Compute a release gate decision from supplied Trivy-style scan results and record it.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The ConfigMap `scan-results` in `starfleet-035-040-02-01` holds a scan report in Trivy JSON shape, and the ConfigMap `scan-exceptions` holds an ignore list. No gate decision has been recorded.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-02-01" || exit 1
node_name="astro-ats-035-lab-040-02-01-control-plane"
worker_name="astro-ats-035-lab-040-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. Read `results.json` from the ConfigMap `scan-results` and the ignore list `trivyignore.txt` from the ConfigMap `scan-exceptions` in the namespace `starfleet-035-040-02-01`.
2. Sort the HIGH and CRITICAL findings: a finding without a fixed version is unfixed, a finding on the ignore list is waived, and every other one is blocking.
3. Create the ConfigMap `scan-gate` in the same namespace with exactly these keys: `decision` (`fail` when any blocking finding remains, otherwise `pass`), `blocking`, `waived` and `unfixed` (each a sorted, comma-separated list of finding identifiers without spaces), `severity` set to `HIGH,CRITICAL` and `ignoreUnfixed` set to `true`.

## Constraints

- Do not change the report or the ignore list.
- The report is test data, and a gate decision is not proof that an image is safe.

## How the answer is checked

The grader computes the gate from the two ConfigMaps and runs three checks against `scan-gate`. The first compares `decision` and `blocking`. The second compares `waived` and `unfixed`. The third compares `severity` and `ignoreUnfixed` and needs no other keys.
