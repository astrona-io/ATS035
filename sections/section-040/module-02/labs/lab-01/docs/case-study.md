---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The ConfigMap `scan-results` in `starfleet-035-040-02-01` holds a scan report in Trivy JSON shape, and the ConfigMap `scan-exceptions` holds an ignore list. No gate decision has been recorded.

Compute a release gate decision from supplied Trivy-style scan results and record it.
