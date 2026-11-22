---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Score A Live Deployment With Kubesec

Scan a live Deployment with Kubesec inside the cluster, raise its score by fixing the findings, and record the final score.

The task and solution use a separate pinned kind cluster. Kubesec runs from the pinned `kubesec/kubesec:v2.15.0` image in the `scanner` pod, so the host needs no Kubesec binary. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
