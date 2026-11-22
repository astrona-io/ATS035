---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Lint A Live Deployment With KubeLinter

Run KubeLinter inside the cluster against a live Deployment, fix its findings, and record one scoped exception with a reason and an owner.

The task and solution use a separate pinned kind cluster. KubeLinter runs from the pinned `stackrox/kube-linter:v0.8.3-alpine` image in the `linter` pod, so the host needs no KubeLinter binary. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
