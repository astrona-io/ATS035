---
draft: true
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Understand The Software Supply Chain

A container image reaches a cluster through a chain of steps: source code, dependencies, a build in a CI/CD pipeline, a registry, and finally a node that pulls it. A CI/CD pipeline is the automated system that builds, tests and publishes software from source code. An attacker who controls any step can change what runs in the cluster, and a defender who cannot list what is inside an image cannot say whether a newly published vulnerability affects it.

Keep one sentence in mind for this module: **know what is in each artifact, know how and where it was built, and know who may change each step.** You will list the images that run in the playground cluster, create a software bill of materials (SBOM) for an image with Syft, scan the image and the SBOM with Trivy, and study how CI/CD pipelines and artifact repositories fit into the chain.

The module has four parts. **Stages, Trust Boundaries And Evidence** maps the chain and lists what each kind of evidence proves. **Software Bills Of Materials With Syft** creates SPDX and CycloneDX documents and compares an SBOM with the packages that the running pod reports. **Vulnerability Scanning With Trivy** scans an image and an SBOM, filters the findings and explains why a result ages. **CI/CD Pipelines And Artifact Repositories** covers credentials, build permissions, registry settings and pull secrets.

## Learning objectives

After this module you can:

- Name the stages of the supply chain and the trust boundary between them.
- Explain what an SBOM, a vulnerability report, a signature and a provenance attestation each prove and do not prove.
- Generate an SBOM in SPDX and CycloneDX formats with Syft and read the package list.
- Scan an image or an SBOM with Trivy, filter by severity and fix state, and use the exit code in a pipeline.
- Describe how to limit credentials in CI/CD and how a cluster authenticates to a private registry.

## Before you start

You need to know what an image, a tag and a digest are, and basic `kubectl` use. Syft and Trivy run on your own machine, so install both before the parts that use them. They are not part of the playground cluster. Trivy downloads its vulnerability database on the first run, so the machine needs network access at that moment.

The playground is a `kind` cluster running Kubernetes 1.35:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas that run `docker.io/library/python:3.13-alpine`, and the `shuttle` client pod that runs `docker.io/library/busybox:1.37.0` |
| `outpost` | The `drifter` client pod that runs `docker.io/library/busybox:1.37.0` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
