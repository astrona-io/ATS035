---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Release A Workload Through Analysis, A Scan Gate And Restricted Admission

Analyse an unsafe workload document, decide a scan gate from a scan report and an ignore list, enforce the restricted Pod Security Standard and run the corrected pod, all in one namespace.

The task and solution use a separate pinned kind cluster. The scan report and the ignore list are fixed inputs in ConfigMaps, so the lab needs no scanner and no vulnerability database. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
