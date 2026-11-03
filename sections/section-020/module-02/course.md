---
draft: true
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Generate And Read Software Bills Of Materials

A software bill of materials (SBOM) is a machine-readable list of the components inside an artifact. A container image can hold hundreds of packages, and nobody can answer "does this image contain the vulnerable library?" by reading a Dockerfile. An SBOM gives that answer in seconds, but only when the reader knows how the document is built, which fields to trust and what the document leaves out.

Keep one sentence in mind for this module: **an SBOM names what is present, tied to the exact image it describes; it does not say what is exploitable.** You will read the structure of the two standard formats, build a component list with package URLs from the packages of a running pod, and study how an SBOM is matched to vulnerability data and attached to an image digest.

The module has two parts. **Reading SPDX And CycloneDX Documents** explains the fields of both formats, the package URL (purl) that names a component, and how a tool such as Syft finds packages. **Matching An SBOM To Vulnerabilities And An Image Digest** covers vulnerability matching, VEX statements, attestations that bind an SBOM to a digest, and the limits of an SBOM.

## Learning objectives

After this module you can:

- Name the main fields of an SPDX document and of a CycloneDX document and say what each one records.
- Write the package URL of an Alpine package from its name and version.
- Explain how a catalog tool such as Syft finds packages and which packages it can miss.
- Explain how a scanner matches SBOM components to vulnerability data and what a VEX statement changes.
- Explain why an SBOM must be bound to an image digest, and how an attestation does it.

## Before you start

You need to know what an image, a tag and a digest are, and basic `kubectl` use. Syft and Trivy are optional for this module. The hands-on steps read package data from the pods in the playground cluster, so they need only `kubectl`. Commands that run Syft or Cosign are marked as commands for your own machine.

The playground is a `kind` cluster running Kubernetes 1.35:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas that run `docker.io/library/python:3.13-alpine`, and the `shuttle` client pod that runs `docker.io/library/busybox:1.37.0` |
| `outpost` | The `drifter` client pod that runs `docker.io/library/busybox:1.37.0` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
