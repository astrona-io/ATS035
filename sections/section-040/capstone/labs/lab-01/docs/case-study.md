---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. Namespace `bay` holds three ConfigMaps: `analysis-source` with a workload document `workload.json` that is not deployed, `scan-results` with a scan report in Trivy JSON shape, and `scan-exceptions` with an ignore list. Namespace `bay` has no Pod Security Admission labels. Nothing is recorded or enforced yet.

Analyse an unsafe workload document, decide a scan gate, enforce restricted admission and run the corrected workload.
