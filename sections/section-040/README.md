---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)

A template appears restricted, but the production overlay adds a writable host mount. Analysis of the source base alone did not evaluate the effective deployment input.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish manifest linting from vulnerability and runtime assessment.
- Explain how Kubesec and KubeLinter identify risky declarations.
- Bind image findings to artifact identity and scanner evidence.
- Evaluate exceptions and admission enforcement without equating scores with safety.
