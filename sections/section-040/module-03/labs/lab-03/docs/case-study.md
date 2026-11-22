---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The namespace `starfleet-035-040-03-03` has no Pod Security Admission labels. It holds three ConfigMaps: `analysis-source` with a workload document that is not deployed, `scan-results` with a scan report in the JSON format of Trivy, and `scan-exceptions` with an ignore list. No findings, gate or corrected pod exist yet.

Analyse an unsafe workload document, decide a scan gate from a scan report and an ignore list, enforce the restricted Pod Security Standard and run the corrected pod, all in one namespace.
