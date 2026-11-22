---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Starting Environment

The namespace `starfleet-035-020-01-03` has the Deployment `probe` with two replicas of `docker.io/library/python:3.13-alpine`. The node pulled the image from the registry by its tag. The Syft 1.57.0 image is already on the node.

Make a CycloneDX software bill of materials (SBOM) with Syft inside the cluster, from the exact image digest that the probe pods run, and store it with that digest.
