---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Prerequisites

Use astrona, kubectl, jq and a shell. Syft runs inside the lab cluster, so you do not install it on your machine. The jq tool filters JSON output on the command line.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-01-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.
