---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Minimize base image footprint

Two `probe` Pods can show the same image tag while using different downloaded content. To explain that difference, separate the image name from the content it identifies and separate the image filesystem from files changed during execution.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Explain image layers and immutable digests.
- Distinguish tags from exact image identity.
- Trace image retrieval and registry authentication.
- Diagnose image selection and pull failures.
