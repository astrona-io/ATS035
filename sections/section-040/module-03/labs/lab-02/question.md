---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce Baseline And Warn On Restricted With Pod Security Admission

Solve this question on: `terminal`

Enforce the baseline Pod Security Standard in a namespace while warning and auditing against restricted, each pinned to v1.35, without stopping the pod that already runs there.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The namespace `hangar-035-040-03-02` has no Pod Security Admission (PSA) labels, so the API server admits every pod there. PSA is the admission controller in the API server that checks pods against the Pod Security Standards. The privileged pod `legacy-scanner` already runs in that namespace, and the team will replace it later. Until then it must keep running.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-02" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Tasks

1. Label the namespace `hangar-035-040-03-02` so that PSA enforces `baseline` and warns and audits `restricted`. Pin each of the three modes to `v1.35` with its `-version` label.
2. Confirm that `legacy-scanner` is still running after the change. Do not delete or recreate it.
3. Create the Deployment `cargo-loader` in `hangar-035-040-03-02` with one replica and one container `loader` that uses `docker.io/library/busybox:1.37.0` and runs `sh -c "while true; do sleep 3600; done"`. Do not add a `securityContext`. Read the warning that `kubectl` prints, and wait until the rollout finishes.
4. Check with a server-side dry run that a pod that sets `privileged: true` is now rejected in `hangar-035-040-03-02`. Do not create it.

## Constraints

- Label only the namespace `hangar-035-040-03-02`.
- Do not change `legacy-scanner` or the `drifter` pod in `outpost-035-040-03-02`.

## How the answer is checked

The grader runs three checks. The first reads the six PSA labels on the namespace. The second makes two server-side dry runs: a privileged pod must be rejected with a `baseline:v1.35` message, and a pod with no `securityContext` must be admitted with a `restricted:v1.35` warning. Neither pod may exist. The third needs `cargo-loader` to be rolled out with a running pod. Every check also needs `legacy-scanner` to be the privileged pod that is still running and ready.
