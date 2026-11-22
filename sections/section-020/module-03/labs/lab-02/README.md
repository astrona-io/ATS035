---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Diagnose A Failed Image Pull And Record The Resolved Image

Read why a pod cannot pull its image, repair the image reference, and record the reference the pod requested next to the image ID that the node resolved.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.

The starting Deployment asks for the tag `1.37.0-scout`, which does not exist on Docker Hub. The bootstrap waits until the pod reports `ErrImagePull` or `ImagePullBackOff`. Without network access the pull also fails, but the event then names a connection error instead of a missing manifest.
