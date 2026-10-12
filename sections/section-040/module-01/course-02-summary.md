---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Summary

Static analysis evaluates declared workload and artifact properties before execution. Manifest tools identify risky settings, while image analysis examines software and vulnerability evidence for exact bytes.

Findings require applicability, exploitability and ownership review. A score or clean report cannot prove runtime safety; release policy should preserve artifact identity, justified exceptions and complementary admission and execution controls.

Static findings support a release decision only within their actual input, rule and artifact scope.
