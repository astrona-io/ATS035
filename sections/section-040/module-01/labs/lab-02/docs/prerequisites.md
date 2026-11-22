---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Prerequisites

Use astrona, kubectl and a shell. KubeLinter runs inside the lab cluster, so you do not install it on your machine.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-01-02" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.
