---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)

A new library vulnerability is announced and someone asks which running images contain it. Without a component list tied to an exact image, nobody can answer, and without control over registries, credentials and builds, nobody can say who could have changed the image. This section teaches how to trace the stages of the supply chain, how to produce and read an SBOM, how to scan, and how to control the registry, the pull credential and the build record.

## Learning Path

1. Understand The Software Supply Chain: stages, trust boundaries, SBOMs with Syft, scanning with Trivy, CI/CD pipelines and artifact repositories.
2. Generate And Read Software Bills Of Materials: SPDX and CycloneDX fields, package URLs, vulnerability matching, VEX statements and attestations bound to an image digest.
3. Provenance, Artifact Repositories And Pull Access: registry roles, immutable tags and retention, pull secrets and service accounts, build provenance and SLSA levels.
4. Capstone: record a release with a package inventory, an image digest, an SBOM format and registry pull access.

Each module ends with a summary. The section ends with one ten-question knowledge check. The parts carry the hands-on steps, and each lab follows the part that practises its skill. Each module has a private `kind` playground with Kubernetes v1.35; launch it from the landing page and keep it running while you read.

## Learning Outcomes

- Trace the trust boundaries from source to deployment.
- Generate and read an SBOM in SPDX and CycloneDX formats, and write the package URL of a component.
- Explain how an SBOM is matched to vulnerabilities and why it must be bound to an image digest.
- Scan an image and filter the result.
- Name controls for pipelines and registries, configure a registry pull secret on a service account and explain what build provenance and the SLSA levels promise.
