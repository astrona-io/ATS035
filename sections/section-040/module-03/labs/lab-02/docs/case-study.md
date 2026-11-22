---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The namespace `hangar-035-040-03-02` has no Pod Security Admission labels. The privileged pod `legacy-scanner` runs there. The namespace `outpost-035-040-03-02` has the pod `drifter`.

Enforce the baseline Pod Security Standard in a namespace while warning and auditing against restricted, each pinned to v1.35, without stopping the pod that already runs there.
