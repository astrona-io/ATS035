---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Bind An SBOM And A VEX Statement To An Image Digest

Bind an SBOM record to the image digest that runs, and record a VEX statement for a scan finding against that digest instead of the tag.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
