---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Combine Registry And Digest Rules In One Admission Policy

Enforce an approved registry and a digest in one ValidatingAdmissionPolicy with a separate message for each rule, apply it to one labelled namespace only, and remove a pod that was admitted before the rule.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass. The graders use server-side dry runs, so the registry `registry.starfleet.test` and the digests in the test pods do not need to exist.
