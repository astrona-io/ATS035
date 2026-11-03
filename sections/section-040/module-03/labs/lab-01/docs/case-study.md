---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `hangar` exists without Pod Security Admission labels, so every pod is accepted there.

Label a namespace to enforce the restricted Pod Security Standard and run one compliant pod while an unrestricted pod is rejected.
