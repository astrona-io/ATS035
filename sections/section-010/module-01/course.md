---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Minimize The Base Image Footprint

A container image is the filesystem and start-up configuration that a container runtime unpacks into a running container. Everything inside that image is part of the attack surface of the workload: every shell, package manager, library and tool that an attacker can use after a first foothold, and every package that can carry a known vulnerability. An image that holds only the application and what it needs at run time gives an attacker less to work with and gives a scanner less to report.

Keep one sentence in mind for this module: **build with everything you need, ship only what you run, and refer to the result by its digest.** You will inspect the images that already run in the playground cluster, build a single-stage and a multi-stage image for a small Go program and compare them, harden a Dockerfile and lint it, and finally run a minimal image in the cluster with a restricted security context.

The module has four parts. **Layers, Tags And Digests** shows what an image is made of and how a tag differs from a digest, using the pods in the cluster. **Multi-Stage Builds And Minimal Base Images** builds the same program twice and compares a full toolchain image with a distroless image. **Hardening A Dockerfile** covers the non-root user, secrets that stay in layers, `.dockerignore`, pinned base images and Dockerfile linting. **Running Minimal Images In A Cluster** applies a read-only, non-root pod, debugs an image that has no shell and reads image pull failures.

## Learning objectives

After this module you can:

- Explain image layers, image manifests, tags and digests, and read the digest of an image that runs in a pod.
- Write a multi-stage Dockerfile that copies only the build result into a distroless or `scratch` final image.
- Remove shells, package managers, build tools and secrets from the final image, and run it as a non-root user.
- Lint a Dockerfile and name the rules that matter for image size and exposure.
- Run a minimal image with a restricted `securityContext`, debug it with an ephemeral container and diagnose an image pull failure.

## Before you start

You need Kubernetes basics: pods, namespaces, Deployments, `kubectl get`, `kubectl apply` and `kubectl exec`. You also need to be able to read a short Dockerfile.

The cluster parts run against your playground cluster, a `kind` cluster running Kubernetes 1.35 with one control plane node and one worker node. The build parts run on your own machine with Podman, the container engine from the introduction. Create a new empty folder for the files you write.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas that run `docker.io/library/python:3.13-alpine`, and the `shuttle` client pod that runs `docker.io/library/busybox:1.37.0` |
| `outpost` | The `drifter` client pod that runs `docker.io/library/busybox:1.37.0` |

The node already holds the `python:3.13-alpine` and `busybox:1.37.0` images, so pods that use them start without a download. Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
