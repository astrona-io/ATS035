---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Require Image Digests And Verify Signatures

A registry rule says where an image comes from. It does not say which build of the image runs, and it does not say who published it. A tag such as `1.37.0` can point at different content tomorrow, and a registry account that is taken over can push a new image under the same name. This module teaches two stronger checks: require that every image is named by its digest, and verify that the content at that digest carries a signature from a signer you trust.

Keep one sentence in mind for this module: **a digest names the exact bytes, a signature names who vouches for them, and only an admission rule makes either one mandatory.** You will write a ValidatingAdmissionPolicy that rejects images without a digest, read how cosign stores signatures and attestations next to an image, compare key-based and keyless signing, and list what admission-time verification cannot prove.

The module has three parts. **A Digest Rule With ValidatingAdmissionPolicy** writes the rule, tests it with server-side dry runs and enforces it. **Signatures, Attestations And Keyless Signing** explains what is stored in the registry and what a verifier checks. **Enforcing Verification And Its Limits** names the components that verify signatures at admission and the gaps that remain.

## Learning objectives

After this module you can:

- Write a ValidatingAdmissionPolicy that requires `@sha256:` and 64 hexadecimal characters in every container, init container and ephemeral container image.
- Roll the rule out with the `Warn`, `Audit` and `Deny` validation actions.
- Explain where cosign stores a signature and an attestation, and what the verifier compares.
- Compare key-based and keyless signing, including the certificate identity, the issuer and the transparency log.
- Explain why CEL cannot verify a signature, name the components that can, and list the limits of verification at admission.

## Before you start

You need `kubectl`, the idea of an image digest, and a basic ValidatingAdmissionPolicy with a binding. The commands run against the playground cluster, a `kind` cluster running Kubernetes 1.35 with one control plane node and one worker node. The signing part names cosign commands that run on your own machine; you do not need to run them to follow the module.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas, and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
