---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Make An SBOM Of A Running Image With Syft

Make a CycloneDX software bill of materials (SBOM) with Syft inside the cluster, from the exact image digest that the probe pods run, and store it with that digest.

The task and solution use a separate pinned kind cluster. Syft runs from the pinned `anchore/syft:v1.57.0` image in a Job, so the host needs no Syft binary. The node pulls `python:3.13-alpine` from the registry at the start, so the pod status reports a repository digest in `imageID`; the first start needs network access to Docker Hub. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
