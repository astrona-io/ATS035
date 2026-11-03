---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Minimize base image footprint

A container image carries every shell, package manager and library that its base image holds, and every one of them is something an attacker can use and a scanner must report. A small image that nobody rebuilds also decays: the base receives fixes that the image never sees. This section teaches how to build, choose, restrict and maintain images so that they hold only what the application needs.

## Learning Path

1. Minimize The Base Image Footprint: layers, tags and digests, multi-stage builds, Dockerfile hardening and minimal images in a cluster.
2. Compare Base Images And Their Attack Surface: Debian, Alpine, distroless and `scratch` images, and how to restrict what a running container can reach.
3. Keep Images Small And Fresh Over Time: digest pins and the tools that update them, image pull policy, rebuild rules, size budgets and registry retention.
4. Capstone: run a hardened minimal web server that combines a small image, a digest pin, a restricted security context and a Service.

Each module has a playground, a graded lab, a summary and a part of the ten-question knowledge check at the end of the section. The playground is a private `kind` cluster with Kubernetes v1.35; launch it from the landing page and keep it running while you read.

## Learning Outcomes

- Explain image layers, tags and digests.
- Build a multi-stage image with a distroless or scratch final stage.
- Harden a Dockerfile and lint it.
- Run a minimal image with a restricted security context and diagnose pull failures.
- Compare base images by what they contain and what they cannot run.
- Pin an image to a digest, explain the image pull policy and plan rebuilds after a base image fix.
