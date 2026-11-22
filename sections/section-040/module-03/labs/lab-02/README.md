---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce Baseline And Warn On Restricted With Pod Security Admission

Enforce the baseline Pod Security Standard in a namespace while warning and auditing against restricted, each pinned to v1.35, without stopping the pod that already runs there.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
