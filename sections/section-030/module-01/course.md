---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Admission Control, Permitted Registries And Signed Images

Knowing what is in an image does not stop a bad image from running. The Kubernetes API server must refuse a pod whose image comes from a registry you do not trust, or whose content nobody signed. Admission control is the stage in the API server that can accept, change or reject a request after the user is authenticated and authorized. This module teaches how that stage works and how to use it to enforce a list of permitted registries and to verify image signatures.

Keep one sentence in mind for this module: **identity is checked at admission, and the policy must name an exact registry or an exact signer.** You will read the admission settings of the playground cluster, write a ValidatingAdmissionPolicy that permits only chosen registries, test what happens when a webhook is unreachable, and sign and verify an image with cosign.

The module has four parts. **The Admission Pipeline And ValidatingAdmissionPolicy** explains the request path and the policy objects. **Enforcing Permitted Registries** writes, tests and enforces a registry policy, and shows its limits. **Policy Engines And Admission Webhooks** covers Kyverno, OPA Gatekeeper, ImagePolicyWebhook and what a failure policy does. **Signing And Verifying Images With cosign** creates a key pair, signs a digest and verifies it.

## Learning objectives

After this module you can:

- Place mutating and validating admission in the order of an API request, and explain what `failurePolicy` decides.
- Write a ValidatingAdmissionPolicy and a binding, and use `Warn` before `Deny`.
- Explain why a Deployment can be admitted while its pods are denied.
- Compare ValidatingAdmissionPolicy, Kyverno, OPA Gatekeeper and ImagePolicyWebhook for image rules.
- Sign an image digest with cosign, verify the signature, and name the difference between key-based and keyless signing.

## Before you start

You need `kubectl`, an understanding of namespaces and labels, and the idea of an image digest. The signing part runs on your machine and uses Podman, cosign and a local registry container. Install cosign before that part.

The playground is a `kind` cluster running Kubernetes 1.35:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas, and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## Independent live assessment

Prepare with [Verify Who Signed An Image Digest](course-04a-verify-image-signature-boundaries.md). [Sign And Verify An Immutable Image](labs/lab-02/question.md) uses its own qemu environment. The supplied immutable image digest has a valid signature under the training public key; A different key and a different unsigned image cannot pass the same verification.
