---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Summary

A registry rule limits where images come from, but a stronger supply chain control names the exact content and the party that vouches for it. The API server can enforce the first with a simple rule, and it needs an extra component for the second.

## What you learned

A digest is the SHA-256 hash of the image manifest, so it names exact bytes. A ValidatingAdmissionPolicy can require that every image in `containers`, `initContainers` and `ephemeralContainers` ends with `@sha256:` and 64 hexadecimal characters. The API server only reads the text of the reference. It does not check that the digest exists. The binding sets the validation actions, and running `Warn` and `Audit` before `Deny` shows what the rule would block. A server-side dry run tests a rule without storing a pod.

Cosign signs an image digest and stores the signature as a separate artifact in the same repository. An attestation is a signed in-toto statement about an image, such as an SBOM or build provenance. Key-based signing relies on one key pair, and the verifier trusts the public key. Keyless signing uses a short-lived Fulcio certificate bound to an OIDC identity and records the event in the Rekor transparency log. The verifier must state the certificate identity and the issuer, or any signer passes.

CEL cannot call a registry, so signature verification needs a component such as Kyverno or the Sigstore policy-controller, which the API server calls as an admission webhook. These checks have limits. A signed image can contain vulnerabilities, a leaked key signs anything, running pods are not checked again, a webhook with `failurePolicy: Ignore` fails open, and excluded namespaces are open.

- Verify and run digests, never tags.
- Name the signer identity and the issuer in the verification policy.
- Use `Fail` for security webhooks and audit pods that already run.
- A signature says who vouches for an image and says nothing about its vulnerabilities.

<!-- astrona:playground:destroy -->
