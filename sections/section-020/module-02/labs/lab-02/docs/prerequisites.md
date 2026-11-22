---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Prerequisites

Use astrona, kubectl and a shell.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-02-02" || exit 1
```

Keep this connection selected. Every command in this lab works on this cluster only.
