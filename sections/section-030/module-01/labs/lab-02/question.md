---
draft: true
---
# Sign And Verify An Immutable Image

Solve this question on: `terminal`

The independent VM has a loopback registry, Cosign, a disposable training key pair and an unsigned image reference in `/srv/signing/image.txt`. The key password is `training-password`. A separate unsigned image is listed in `/srv/signing/unsigned.txt`.

Allow about 15 minutes for the tasks.

## Tasks

1. Sign the exact image digest using `/srv/signing/training.key`. Store the signature in the local registry and verify it using `/srv/signing/training.pub`.
2. Verify the same signed image fails under `/opt/astrona-live/other.pub`, and the other unsigned image fails under the training public key. Inspect the accepted signature's digest claim.

## Constraints

Preserve the images, reference files and key pairs. Use `--allow-insecure-registry` only for this isolated loopback HTTP registry. Disable transparency-log upload for signing and explicitly ignore transparency-log verification for this local key exercise; do not disable signature or digest verification.

## How the answer is checked

The grader independently verifies the registry signature against the expected public key and immutable digest. It also attempts verification with the wrong key and against the unsigned digest while checking registry health.
