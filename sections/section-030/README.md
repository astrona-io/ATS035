---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Secure your supply chain (permitted registries, sign and validate artifacts, etc.)

A cluster that runs any image from any registry trusts every registry on the internet. This section teaches how the API server decides which images may run: which registries are permitted, whether an image must be named by its digest, whether its signature is verified, how pull credentials reach the node, and which settings can switch a check off without deleting it.

## Learning Path

1. Admission Control, Permitted Registries And Signed Images: the admission pipeline, ValidatingAdmissionPolicy, permitted registries, webhooks and policy engines, and signing with cosign.
2. Require Image Digests And Verify Signatures: a digest rule, signatures and attestations, key-based and keyless signing, and the limits of verification at admission.
3. ImagePullSecrets, ImagePolicyWebhook And Admission Failure Modes: pull credentials, the ImagePolicyWebhook plugin, and audit-only, fail-open and exempted checks.
4. Capstone: enforce an approved registry and a digest requirement in one policy set while a system namespace stays exempt.

Each module has a playground, a summary and a graded lab. The section has one knowledge check with ten questions that covers all three modules.

## Learning Outcomes

- Place admission in the API request path.
- Write and test a permitted-registries policy and a digest policy.
- Compare webhooks, Kyverno and Gatekeeper and set failure policy.
- Sign and verify an image digest with cosign, and name the identity and the issuer in keyless verification.
- Create image pull secrets and attach them to a ServiceAccount.
- Explain the `defaultAllow` setting of ImagePolicyWebhook and find audit-only, fail-open and exempted checks.
