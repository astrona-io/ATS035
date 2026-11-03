---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)

A manifest can look harmless and still ask for a privileged container, and an image can carry a package with a known flaw. Static analysis finds both before anything runs, but it reads only what is declared or installed, so each tool answers one question. This section teaches what each tool reads, how to turn its report into a decision, and how the cluster enforces a minimum when a person skips the pipeline.

## Learning Path

1. Static Analysis Of Workloads And Images: what static analysis shows, Kubesec, KubeLinter, and a release decision.
2. Scan Images And Configuration With Trivy: image, folder and configuration scans, severity and exit-code gates, exceptions and database freshness.
3. Enforce Workload Standards With Pod Security Admission: the Pod Security Standards, namespace labels, modes and versions, the restricted standard and exemptions.
4. Capstone: analyse an unsafe workload, decide a scan gate, enforce the restricted standard and run the corrected workload.

Each module has a playground, a graded lab, a summary and, together with the other modules of the section, a ten-question knowledge check. The capstone is one advanced lab in its own environment.

## Learning Outcomes

- State what static analysis reads and what it cannot see.
- Scan a manifest with Kubesec and read the report.
- Lint with KubeLinter and record a scoped exception.
- Choose between `trivy image`, `trivy fs` and `trivy config`, and build a gate from severity, unfixed and exit-code options.
- Record a time-limited scan exception and explain what a finding does and does not prove.
- Enforce the restricted Pod Security Standard on a namespace and preview a label change with a server-side dry run.
- Combine manifest, image and cluster evidence in a release decision.
