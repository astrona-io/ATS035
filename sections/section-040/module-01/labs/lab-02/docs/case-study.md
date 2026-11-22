---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The namespace `starfleet-035-040-01-02` has the Deployment `lint-probe`, which runs a privileged BusyBox container with no user and no resource settings. The pod `linter` runs KubeLinter 0.8.3 and mounts the team configuration from the ConfigMap `lint-policy` at `/policy/kube-linter.yaml`.

Run KubeLinter inside the cluster against a live Deployment, fix its findings, and record one scoped exception with a reason and an owner.
