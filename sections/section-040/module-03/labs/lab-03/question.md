---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Release A Workload Through Analysis, A Scan Gate And Restricted Admission

Solve this question on: `terminal`

Analyse an unsafe workload document, decide a scan gate from a scan report and an ignore list, enforce the restricted Pod Security Standard and run the corrected pod, all in one namespace.

Allow about 15 minutes for the tasks. Cluster startup adds time.

## Starting state

A team wants to release a reader pod into `starfleet-035-040-03-03`. Before the release, three checks must agree: a static review of the workload document, a gate on the image scan, and Pod Security Admission in the namespace. Pod Security Admission is the built-in admission controller that checks each new pod against a Pod Security Standard that the namespace labels name.

The namespace holds three ConfigMaps that you must not change:

- `analysis-source`, key `workload.json`: the pod document that the team first wrote. It is not deployed.
- `scan-results`, key `results.json`: a scan report of the image in the JSON format of Trivy. Each finding has a `VulnerabilityID`, a `Severity` and a `FixedVersion`, which is empty when no fixed version exists.
- `scan-exceptions`, key `trivyignore.txt`: the ignore list, with one identifier per line and comments that start with `#`.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Tasks

1. Read `workload.json` without deploying it. Create the ConfigMap `analysis-findings` with four keys: `privileged` set to `true` or `false` as the container sets it, `runAsNonRoot` set to `missing` or `present` for the pod `securityContext`, `allowPrivilegeEscalation` set to `missing` or `present` for the container `securityContext`, and `imageTag` set to the tag of the image.
2. Decide the scan gate from `results.json` and `trivyignore.txt` with these rules: only findings with severity `HIGH` or `CRITICAL` count; a counted finding with no fixed version is unfixed; a counted finding on the ignore list is waived; every other counted finding is blocking. Create the ConfigMap `scan-gate` with the keys `decision` (`fail` when a blocking finding remains, otherwise `pass`), `blocking`, `waived` and `unfixed` (sorted identifiers, separated by commas, no spaces), `severity` set to `HIGH,CRITICAL` and `ignoreUnfixed` set to `true`.
3. Label the namespace `starfleet-035-040-03-03` with `pod-security.kubernetes.io/enforce=restricted`, `pod-security.kubernetes.io/enforce-version=v1.35`, `pod-security.kubernetes.io/warn=restricted` and `pod-security.kubernetes.io/audit=restricted`.
4. Create the pod `corrected-reader` in `starfleet-035-040-03-03` with `restartPolicy: Never`, one container `reader` with the image `docker.io/library/busybox:1.37.0` and the command `sh -c "sleep 3600"`, `runAsNonRoot: true`, `runAsUser: 1000` and `runAsGroup: 1000` and the `RuntimeDefault` seccomp profile at pod level, and `allowPrivilegeEscalation: false` with all capabilities dropped on the container. It must be Ready.

## Constraints

- Do not change the ConfigMaps `analysis-source`, `scan-results` and `scan-exceptions`.
- Do not deploy the document in `workload.json`. The namespace must reject it.
- Do not change the `drifter` pod in `outpost-035-040-03-03`.

## How the answer is checked

The grader runs four checks. The first reads the namespace labels, sends the document from `workload.json` to the API server as a server-side dry run, which must fail with `violates PodSecurity`, and confirms that no `unsafe-source` pod exists. The second compares `analysis-findings` with the facts of the document. The third computes the gate from the two ConfigMaps with the rules above and needs every key of `scan-gate` to match. The fourth compares `corrected-reader` with the required fields and needs it to be running and ready. Every check also confirms that the three source ConfigMaps are unchanged.
