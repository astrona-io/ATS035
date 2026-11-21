---
draft: true
---
# Verify Who Signed An Image Digest

An image digest identifies content but does not identify who approved it. Cosign signs a digest and stores a signature artifact with the image in a registry. Verification needs a trusted key and the intended digest. Accepting whichever key accompanies an artifact would let an untrusted publisher choose its own authority.

This independent VM supplies two disposable key pairs and a loopback registry. The exercise uses local key trust, not keyless identity or a public transparency log. Run commands inside the VM.

<!-- astrona:playground:renew -->

Read the immutable image reference and sign it:

```sh
image=$(cat /srv/signing/image.txt)
COSIGN_PASSWORD=training-password cosign sign --yes --use-signing-config=false --key /srv/signing/training.key --tlog-upload=false --allow-insecure-registry "$image"
cosign verify --key /srv/signing/training.pub --insecure-ignore-tlog=true --allow-insecure-registry "$image"
```

The accepted JSON contains `critical.image.docker-manifest-digest`. Compare it with the digest after `@` in `/srv/signing/image.txt`. A tag can move; the digest remains bound to the signed content.

Exercise both rejection cases:

```sh
cosign verify --key /opt/astrona-live/other.pub --insecure-ignore-tlog=true --allow-insecure-registry "$image"
unsigned=$(cat /srv/signing/unsigned.txt)
cosign verify --key /srv/signing/training.pub --insecure-ignore-tlog=true --allow-insecure-registry "$unsigned"
```

Both should fail for signature reasons. A connection error proves only that the registry cannot be reached, so verify registry health with `curl --fail http://127.0.0.1:5000/v2/` and keep the successful trusted-key check as a control.

The lab's HTTP and transparency-log exceptions keep this disposable exercise independent of public identities and services. They do not disable cryptographic signature checking. Production workflows need their own trusted key or identity policy, registry TLS, key handling and transparency requirements.

## Common pitfalls

> [!WARNING]
> A valid signature establishes that the holder of the trusted key signed these bytes. It does not prove the image is vulnerability-free or that its build process was trustworthy. Keep signature verification, vulnerability policy and provenance evaluation as separate decisions.
