---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Lint A Live Deployment With KubeLinter

Solve this question on: `terminal`

Run KubeLinter inside the cluster against a live Deployment, fix its findings, and record one scoped exception with a reason and an owner.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Starting state

The team must clear the `lint-probe` Deployment in `starfleet-035-040-01-02` before the next release. It runs a privileged BusyBox container as root, with no CPU or memory settings.

KubeLinter is a static analysis tool that checks Kubernetes objects against named checks. It runs in the pod `linter` in the same namespace. The team configuration is in the ConfigMap `lint-policy` and is mounted in that pod at `/policy/kube-linter.yaml`. It turns off the default checks and includes only these seven: `privileged-container`, `privilege-escalation-container`, `run-as-non-root`, `no-read-only-root-fs`, `latest-tag`, `unset-cpu-requirements` and `unset-memory-requirements`.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-01-02" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

This command sends the live Deployment to KubeLinter in the `linter` pod. The `-` at the end tells KubeLinter to read the object from its standard input:

```sh
kubectl -n starfleet-035-040-01-02 get deployment lint-probe -o yaml |
  kubectl -n starfleet-035-040-01-02 exec -i linter -- /kube-linter lint --config /policy/kube-linter.yaml -
```

## Tasks

1. Run the lint command above and read each finding: the check name, the object and the remediation.
2. Fix the Deployment `lint-probe`: keep the image `docker.io/library/busybox:1.37.0`, remove `privileged: true`, set `allowPrivilegeEscalation: false` on the container `app`, set `runAsNonRoot: true` and `runAsUser: 10001` at pod level, and set CPU and memory requests and limits on the container `app`. Keep its command unchanged.
3. The application writes `/tmp/last-run` in its root filesystem, so the team accepts the `no-read-only-root-fs` finding. Record it on the Deployment metadata with the annotation `ignore-check.kube-linter.io/no-read-only-root-fs`. Its value gives the reason and then the owner, in the form `<reason>; owner: <team>`.
4. Run the lint command again. KubeLinter must report no findings, and the new pod must be running.

## Constraints

- Do not change the ConfigMap `lint-policy` or the pod `linter`.
- Except only the `no-read-only-root-fs` check. Do not add any other `kube-linter.io` annotation.
- Do not change the `drifter` pod in `outpost-035-040-01-02`.

## How the answer is checked

The grader runs three checks. The first reads the live Deployment, rejects any KubeLinter annotation except the one exception, and runs KubeLinter itself in the `linter` pod with the team configuration: it must report no findings. The second reads the exception annotation and needs a reason followed by `owner:` and a team. The third needs the rollout to be complete and every running `lint-probe` pod to use `busybox:1.37.0`, run as user 10001 and have written `/tmp/last-run`. Every check also confirms that `lint-policy` and `linter` are unchanged.
