---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Secure your supply chain (permitted registries, sign and validate artifacts, etc.)

A validating webhook cannot be reached. Its configured failure policy determines whether affected requests are rejected or can continue. Policy availability and security coverage therefore interact.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Distinguish mutation, validation and authorization.
- Explain built-in, declarative and webhook admission mechanisms.
- Relate failure policy and exemptions to effective enforcement.
- Identify extension credentials, transport and availability requirements.
