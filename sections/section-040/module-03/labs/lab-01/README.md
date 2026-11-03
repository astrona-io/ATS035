---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce The Restricted Pod Security Standard

Label a namespace to enforce the restricted Pod Security Standard and run one compliant pod while an unrestricted pod is rejected.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
