---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Score A Live Deployment With Kubesec

Solve this question on: `terminal`

Scan a live Deployment with Kubesec inside the cluster, raise its score by fixing the findings, and record the final score.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Starting state

The security team gives every Deployment a Kubesec score before release. The `score-probe` Deployment in `starfleet-035-040-01-03` runs a privileged BusyBox container as root, with no CPU or memory settings, and it does not pass.

Kubesec is a static analysis tool that reads a Kubernetes object and gives it a numeric score. Each security setting that is present adds points, and each dangerous setting, such as a privileged container, takes points away and appears in the `critical` list. Kubesec runs in the pod `scanner` in the same namespace.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-01-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

This command sends the live Deployment to Kubesec in the `scanner` pod. The `-` at the end tells Kubesec to read the object from its standard input. Kubesec prints a JSON report:

```sh
kubectl -n starfleet-035-040-01-03 get deployment score-probe -o yaml |
  kubectl -n starfleet-035-040-01-03 exec -i scanner -- kubesec scan -
```

## Tasks

1. Run the scan command above. Read the `score`, the `critical` list and the `advise` list.
2. Fix the Deployment `score-probe` so that Kubesec reports no critical finding and a score of at least 10. Keep the image `docker.io/library/busybox:1.37.0` and keep its command unchanged. The container must run as the numeric user 10001 and must still write `/tmp/last-run`.
3. Run the scan again. Create the ConfigMap `kubesec-report` in `starfleet-035-040-01-03` with two keys: `object` set to `deployment/score-probe`, and `score` set to the score that Kubesec reports now.

## Constraints

- Do not change the pod `scanner`.
- Keep one replica of `score-probe`.
- Do not change the `drifter` pod in `outpost-035-040-01-03`.

## How the answer is checked

The grader runs three checks. The first sends the live Deployment to Kubesec in the `scanner` pod: the report must be valid, with no critical finding and a score of at least 10. The second reads `kubesec-report`: `object` must be `deployment/score-probe` and `score` must equal the score that Kubesec reports for the live Deployment at grading time. The third needs the rollout to be complete and every running `score-probe` pod to use `busybox:1.37.0`, run as user 10001 and have written `/tmp/last-run`. Every check also confirms that `scanner` is unchanged and ready.
