---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Starting Environment

The namespace `starfleet-035-030-02-02` has no admission policy and runs the pod `legacy-scout` with a tag-only image from Docker Hub. The namespace `outpost-035-030-02-02` carries the label `training.astrona.io/release-gate: exempt` and runs the pod `drifter`.

Enforce an approved registry and a digest in one ValidatingAdmissionPolicy with a separate message for each rule, apply it to one labelled namespace only, and remove a pod that was admitted before the rule.
