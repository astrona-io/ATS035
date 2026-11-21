---
draft: true
---
# Solution

Sign and verify the supplied digest:

```sh
image=$(cat /srv/signing/image.txt)
COSIGN_PASSWORD=training-password cosign sign --yes --use-signing-config=false --key /srv/signing/training.key --tlog-upload=false --allow-insecure-registry "$image"
cosign verify --key /srv/signing/training.pub --insecure-ignore-tlog=true --allow-insecure-registry "$image"
```

Run the preparation lesson's wrong-key and unsigned-image checks. Both must fail while the trusted signed digest passes.
