---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Starting Environment

The namespace `starfleet-035-020-02-02` runs two `probe` replicas from `docker.io/library/python:3.13-alpine`. The ConfigMap `sbom-record` names that tag as its `subject`. The ConfigMap `scan-finding` holds a training finding, `TRAINING-2026-0001`, also recorded against the tag. No VEX statement exists.

Bind an SBOM record to the image digest that runs, and record a VEX statement for a scan finding against that digest instead of the tag.
