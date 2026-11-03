---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Keep Images Small And Fresh Over Time

A minimal image is not minimal for long. The packages in its base image receive security fixes, a tag moves to new content, and the size of the image grows with every change. An image that was a good choice at release time becomes a liability when nobody rebuilds it. This module covers how to keep a small image exact and current.

Keep one sentence in mind for this module: **name the exact content that runs, and replace that content on a schedule and whenever a fix is published.** You will read digests in the playground cluster, run a workload that is pinned to a digest, and watch how the image pull policy decides when a node downloads an image.

The module has two parts. **Pin Images By Digest And Keep The Pin Current** explains digest pinning and the tools that update pins. **Pull Policy, Rebuild Cadence And Size Budgets** explains `imagePullPolicy`, the rebuild rules after a vulnerability fix, size budgets and registry retention.

## Learning objectives

After this module you can:

- Read the digest of a running container and write an image reference that uses it.
- Explain why a pinned digest needs an update process and name tools that automate it.
- Explain how `imagePullPolicy` and the tag decide when a node pulls an image.
- Describe when to rebuild an image and why a base image fix does not reach an existing image by itself.
- Describe a size budget, a `.dockerignore` file and registry retention rules.

## Before you start

You need to know what an image tag and a digest are and how to run `kubectl get` and `kubectl apply`. The playground is a `kind` cluster running Kubernetes 1.35 with one control plane node and one worker node.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas that run `docker.io/library/python:3.13-alpine`, and the `shuttle` client pod that runs `docker.io/library/busybox:1.37.0` |
| `outpost` | The `drifter` client pod that runs `docker.io/library/busybox:1.37.0` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
