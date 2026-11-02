---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)

A compiler stage uses a private credential, then a later layer deletes its file. The deletion does not prove that earlier distributed image content never exposed it.

The explanations identify the responsible components, compare intended and observed state, and work through the decisions needed to preserve the requirement. Read the worked examples as reasoning about a proposed system; no environment is started by this section.

Read the module goals, teaching and closing summary in order. YAML checks are indexed separately and appear after designated summaries. Larger domains include an intermediate checkpoint before the final review.

## Learning Outcomes

- Trace source, build, publication and deployment trust boundaries.
- Distinguish provenance, signatures, inventories and vulnerability findings.
- Relate admission decisions to exact artifact identity.
- Explain continued maintenance after an artifact is approved.
