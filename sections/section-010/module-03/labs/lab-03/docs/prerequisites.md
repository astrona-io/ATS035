---
exam_objectives:
- Minimize base image footprint
---
# Prerequisites

Use astrona, kubectl and a shell. You should know how to write a Deployment, a ConfigMap and a Service in YAML.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.
