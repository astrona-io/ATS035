---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Static Analysis Of Workloads And Images

Static analysis reads a manifest or an image and reports risks without running the workload. It is cheap, fast and works before anything reaches the cluster, so it is the first gate in a release. It also has limits: it sees what is declared, not what happens at run time.

This module teaches what static analysis can and cannot show, how to scan a manifest with Kubesec, how to lint it with KubeLinter, and how to combine these tools with an image scan and Pod Security Admission to make a release decision.

## Learning Goals

- Explain what a static check reads, what it cannot see and why the rendered manifest is the right input.
- Scan a manifest with Kubesec and read its score, critical findings and advice.
- Lint manifests with KubeLinter, choose checks, and record a justified exception.
- Combine manifest findings, an image scan and Pod Security Admission into a release decision.

## Before You Start

You need a terminal with `kubectl`. The Kubesec, KubeLinter and Trivy commands run on your own machine, so install them before the parts that use them. Cluster checks use the playground cluster.

## Reading Order

1. What static analysis can and cannot show
2. Scanning manifests with Kubesec
3. Linting manifests with KubeLinter
4. A release decision with image scans and Pod Security Admission
5. Summary

<!-- astrona:playground -->
