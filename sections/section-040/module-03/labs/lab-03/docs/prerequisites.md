---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Prerequisites

Use astrona, kubectl, jq and a shell. The jq tool filters JSON output on the command line.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.
