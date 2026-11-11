---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Summary

Authorization decides who may create a pod, and admission control decides whether the content of the request is acceptable. Image rules belong at admission, because a cluster that accepts any image from any registry trusts every registry on the internet.

## What you learned

An API request passes authentication, authorization, mutating admission, schema validation and validating admission before the API server writes it to etcd. Mutating steps run first, so validating rules see the final object. ValidatingAdmissionPolicy is a CEL policy that runs inside the API server and is generally available since Kubernetes 1.30. It needs a ValidatingAdmissionPolicyBinding to take effect, and the binding sets `validationActions` to `Deny`, `Warn` or `Audit`. ImagePolicyWebhook is an admission plugin that is off by default and sends an `ImageReview` to an external backend, and its `defaultAllow` setting decides what happens when the backend is down.

A permitted-registries rule compares the image string in the pod with prefixes that end in `/`. It must cover `containers`, `initContainers` and `ephemeralContainers`, and it needs full registry names because the API server does not expand short names. It matches pods, so a Deployment with a bad image is admitted while its ReplicaSet fails to create pods, and the reason appears in events. Running a policy with `Warn` and `Audit` first, and testing with `--dry-run=server`, shows the impact before enforcement.

Admission webhooks receive an `AdmissionReview` over HTTPS. `failurePolicy: Fail` rejects requests when the webhook fails, and `Ignore` allows them, so a security webhook should use `Fail`, run with several replicas and exclude its own namespace. Kyverno uses YAML policies and can verify signatures and mutate tags to digests. OPA Gatekeeper uses Rego in a ConstraintTemplate and constraints with parameters. CEL cannot call a registry, so it cannot verify a signature.

Cosign signs an image digest and stores the signature in the registry next to the image. Key-based signing uses a key pair that the owner must protect. Keyless signing uses an OIDC identity, a short-lived Fulcio certificate and the Rekor transparency log, and the verifier checks the identity and the issuer. A signature proves who published the content and says nothing about vulnerabilities. Verification works only when an admission rule requires it.

- A policy without a binding does nothing.
- Use `Fail` on security webhooks and exclude their own namespace.
- Sign and verify digests, never tags.
- Name the trusted key or identity in the verification policy.



## Independent live assessment

Prepare with [Verify Who Signed An Image Digest](course-04a-verify-image-signature-boundaries.md). [Sign And Verify An Immutable Image](labs/lab-02/question.md) uses its own qemu environment. The supplied immutable image digest has a valid signature under the training public key; A different key and a different unsigned image cannot pass the same verification.

<!-- astrona:playground:destroy -->
