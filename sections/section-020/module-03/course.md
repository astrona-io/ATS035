---
draft: true
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Provenance, Artifact Repositories And Pull Access

An image is only as trustworthy as the place it is stored and the record of how it was built. A registry that anyone can push to lets an attacker replace an image. A cluster that pulls with a shared administrator credential lets one stolen secret reach every repository. A build with no record cannot be checked later. This module covers the three controls that close those gaps: access rules on the artifact repository, narrow pull credentials in the cluster, and provenance for the build.

Keep one sentence in mind for this module: **few identities may push, each workload may pull only what it needs, and every artifact carries a record of how it was built.** You will read the roles around a registry, create a registry pull secret and bind it to a service account, and study build provenance and the SLSA levels.

The module has three parts. **Registries, Repositories And Who May Push Or Pull** explains the objects in a registry, immutable tags, retention and separate roles for push and pull. **Pull Secrets And Service Accounts** shows how the kubelet gets credentials and how to attach a pull secret to a service account. **Build Provenance And SLSA Levels** explains provenance, what each SLSA build level promises and how a consumer checks it.

## Learning objectives

After this module you can:

- Describe a registry, a repository, a tag and a digest, and name the controls a registry should enforce.
- Separate the roles that push images from the roles that pull them.
- Create a `kubernetes.io/dockerconfigjson` secret and attach it to a service account so that pods receive it.
- Explain what build provenance records and what the SLSA build levels 1 to 3 promise.

## Before you start

You need to know what an image, a tag and a digest are, and basic `kubectl` use with namespaces, secrets and service accounts.

The playground is a `kind` cluster running Kubernetes 1.35. It also has a service account named `probe-runner` in the `starfleet` namespace:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas that run `docker.io/library/python:3.13-alpine`, the `shuttle` client pod that runs `docker.io/library/busybox:1.37.0` and the `probe-runner` service account |
| `outpost` | The `drifter` client pod that runs `docker.io/library/busybox:1.37.0` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->

## Independent live assessment

Prepare with [Prove An Image Pull Uses Registry Credentials](course-02a-prove-an-authenticated-pull.md). [Repair Authenticated Image Pulls](labs/lab-01/question.md) uses its own kind environment. The pull Secret authenticates to the live private registry; ServiceAccount probe-runner lists registry-credentials in imagePullSecrets; A fresh Pod pulls and runs the private image using the ServiceAccount credential.
