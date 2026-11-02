---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Signing And Verifying Images With cosign

A registry rule says where an image comes from. It cannot say that the bytes at that address are the ones your pipeline built, because anyone with write access to the repository can push other content under the same tag. A digital signature closes that gap. The signer creates a signature over the image digest with a private key, and every verifier checks it with the matching public key or identity. This part signs an image in a local registry, verifies it, shows what a failed verification looks like and explains how a cluster enforces signatures.

## What cosign does

Cosign is the signing tool of the Sigstore project. It signs a container image **digest** and stores the signature in the same registry, as a separate artifact that refers to the image digest. The image itself does not change, and its digest stays the same. A verifier looks up the signature for the digest and checks it.

Two signing modes exist:

- **Key-based signing.** You create a key pair with `cosign generate-key-pair`. The private key (`cosign.key`) signs, and the public key (`cosign.pub`) verifies. You must protect and rotate the private key, usually in a key management service.
- **Keyless signing.** The signer logs in with an OpenID Connect (OIDC) identity, such as a CI job identity. Sigstore's certificate authority, Fulcio, issues a short-lived certificate that binds a key to that identity, and Rekor, a transparency log, records the signature. The verifier then checks the identity and the issuer, with `--certificate-identity` and `--certificate-oidc-issuer`, not a long-lived key. There is no private key to steal.

Sign the digest and not the tag. A tag can move after you signed it, and a verifier that resolves the tag later would then check a different image.

## Prepare a local registry and an image

The exercise runs on your machine. It starts a registry container, pushes an image to it and records its digest. Cosign flags change between major versions, so run `cosign sign --help` and `cosign verify --help` if a flag below is not accepted by your version.

<!-- astrona:playground:renew -->

```sh
podman run -d --name local-registry -p 5000:5000 docker.io/library/registry:2
podman pull docker.io/library/busybox:1.37.0
podman tag docker.io/library/busybox:1.37.0 localhost:5000/starfleet/shuttle:1.0
podman push --tls-verify=false --digestfile shuttle.digest localhost:5000/starfleet/shuttle:1.0
cat shuttle.digest
```

The file `shuttle.digest` holds the digest of the pushed manifest, in the form `sha256:` and 64 hexadecimal characters. Use this digest in every command below, because the signature refers to it. Create the key pair. Cosign asks for a password, and you can use any password for this exercise:

```sh
cosign generate-key-pair
```

The command writes `cosign.key` and `cosign.pub` in the current folder. Sign the image by its digest. The registry runs without TLS, so the command needs the option that allows an insecure registry, and a local test does not upload to the public transparency log:

```sh
cosign sign --key cosign.key --allow-insecure-registry --tlog-upload=false "localhost:5000/starfleet/shuttle@$(cat shuttle.digest)"
```

Cosign asks for the key password, then pushes the signature to the registry. Verify with the public key:

```sh
cosign verify --key cosign.pub --allow-insecure-registry --insecure-ignore-tlog=true "localhost:5000/starfleet/shuttle@$(cat shuttle.digest)"
```

A successful verification prints the checks that cosign performed and a JSON payload. The payload contains the repository and the digest that the signature covers. If you verify with a different public key, or if no signature exists for the digest, the command exits with an error such as "no signatures found" or "no matching signatures".

## A verification failure

The signature belongs to one digest in one repository. Push the same image to a second repository, where nobody signed it, and try to verify it there:

```sh
podman tag docker.io/library/busybox:1.37.0 localhost:5000/starfleet/other:1.0
podman push --tls-verify=false localhost:5000/starfleet/other:1.0
cosign verify --key cosign.pub --allow-insecure-registry --insecure-ignore-tlog=true "localhost:5000/starfleet/other@$(cat shuttle.digest)"
```

The verification fails with a message that no signatures were found, although the image content is the same. This is the correct behaviour: the policy asks for a signature in the place where the cluster pulls from. Remove the exercise containers when you finish:

```sh
podman rm -f local-registry
```

## Enforce signatures in the cluster

Running `cosign verify` by hand protects nothing. The cluster must run the check at admission, for every pod. Two usual ways exist:

- A policy engine with a verification rule. Kyverno's `verifyImages` rule takes `imageReferences` (the images it applies to) and `attestors` (the keys or the keyless identities that must have signed), checks the signature through the registry, and can rewrite the tag to the verified digest so that the pod runs exactly what was checked.
- A dedicated admission controller, such as the Sigstore policy controller, which uses a `ClusterImagePolicy` object with the same two inputs.

The built-in ValidatingAdmissionPolicy cannot verify a signature, because CEL cannot contact a registry. It can still enforce a related, weaker rule: require that every image reference contains a digest. In CEL this check is `c.image.contains('@sha256:')`. The rule makes sure the pod names exact content, and a signature check by an engine then proves who published it.

The full chain has three links that the verifier must hold together: the image reference names a digest, the signature covers that digest, and the policy names the key or the identity that is trusted. If one link is missing, for example a policy that accepts any signer, the signature adds little.

You now know how to sign a digest, verify it with a key, tell a key-based flow from a keyless one and place the verification at admission. Signing proves who published an image. It does not prove that the image is free of vulnerabilities, so signatures, scans and registry rules each cover one question.

## Common pitfalls

> [!WARNING]
> - **Signing a tag.** A moved tag points to unsigned content. Sign and verify the digest.
> - **Verifying without naming the signer.** A check that accepts any valid signature accepts an attacker's own signature. Pass the public key or the exact identity and issuer.
> - **Keeping the private key in the pipeline repository.** Anyone who reads it can sign. Use a key management service or keyless signing.
> - **Verifying only by hand.** Without an admission rule, nothing stops an unsigned pod from running.
> - **Reading a valid signature as a clean image.** A signature says who published the content. A scan says what is known about it.
