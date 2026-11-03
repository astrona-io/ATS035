---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforcing Verification And Its Limits

A signature that nobody checks protects nothing. The check must happen at a point that every pod passes through, which is admission. This part names the components that verify signatures when a pod is created, shows what a verification policy contains, and lists what the check cannot prove.

## Who verifies at admission

A ValidatingAdmissionPolicy runs CEL inside the API server. CEL has no function that calls a registry or checks a signature, so the built-in policy can test the text of an image reference and nothing more. Signature verification therefore needs a component that can reach the registry and check cryptography. Two common choices run as admission webhooks, which are HTTPS services that the API server calls:

- **Kyverno** is a policy engine. Its `verifyImages` rule checks signatures and attestations, and it can also replace a tag with the verified digest in the pod.
- **The Sigstore policy-controller** is an admission controller from the Sigstore project. A `ClusterImagePolicy` object lists the image patterns and the keys or keyless identities that must sign them.

Both components receive the pod from the API server, pull the signature and attestation from the registry, verify them against the policy and answer allow or deny. The next policy is Kyverno YAML. It needs Kyverno installed, which the playground does not include, so read it and do not apply it. Replace the placeholders with real values:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: Enforce
  webhookConfiguration:
    failurePolicy: Fail
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds: ["Pod"]
      verifyImages:
        - imageReferences: ["<REGISTRY>/<TEAM>/*"]
          attestors:
            - entries:
                - keys:
                    publicKeys: "<PUBLIC_KEY>"
```

The rule applies to pods, checks every image that matches the pattern and requires a signature from the listed public key. The field names can change between Kyverno versions, so compare the file with the documentation of the version you install. Images outside the pattern are not checked, so the pattern must cover every registry path you allow.

## What the check cannot prove

Verification at admission is strong for one question: did the trusted signer sign this digest? It leaves other questions open.

- **A signed image can be vulnerable.** The signer signs what the build produced, including old libraries. Scanning and patching are separate work.
- **A leaked key or a hijacked identity signs anything.** The verifier trusts whoever holds the key or the identity.
- **Running pods are not checked again.** Admission runs when a pod is created or updated. A pod admitted yesterday keeps running if you remove the signature or change the policy.
- **A broken webhook can allow everything.** If the webhook uses `failurePolicy: Ignore`, a crash of the service turns the check off without any error for users.
- **Exempted namespaces are open.** Every namespace that the policy excludes can run unsigned images.
- **The registry can still be slow or unavailable.** Verification needs the registry at admission time, and an outage can block new pods.

## Try it in the playground

You can measure one of these gaps in the playground. List every pod in the cluster whose container image reference has no digest. These pods ran without the rule you wrote earlier:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-030-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-030-02" || exit 1
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" "}{.spec.containers[*].image}{"\n"}{end}'
```

Read the image column. Pods that show a tag and no `@sha256:` would be rejected by a digest rule, and enforcing the rule later does not remove them. To find such pods in your own clusters before you enforce, run this kind of listing first, then fix the manifests and roll the workloads. You can also ask the API server which webhook configurations exist, to see whether an image verification webhook is registered:

```sh
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

The playground shows no image verification webhook, because none is installed. A real cluster that enforces signatures lists the webhook configuration of its engine here, with a `failurePolicy` you should check.

You now know where verification runs, what it covers and where it stops. A complete supply chain control combines a permitted registry, a digest rule, a signature check and a plan to rescan and update what already runs.

## Common pitfalls

> [!WARNING]
> - **Assuming CEL verifies signatures.** A ValidatingAdmissionPolicy only reads the request. Use an engine that can call the registry.
> - **Writing an image pattern that is too narrow.** An image outside every pattern passes without any check.
> - **Using `Ignore` for a security webhook.** An outage then disables the control silently.
> - **Forgetting running pods.** Admission checks new requests. Audit existing workloads on a schedule.
