---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Compare Base Images And Their Attack Surface

The base image is the first layer of a container image and decides most of what the final image contains. A Debian base brings a shell, a package manager and hundreds of packages. A distroless base brings only the files a program needs. Choosing the base is the largest single decision for the size and exposure of an image, and it is the decision that a security review of a Dockerfile looks at first.

Keep one sentence in mind for this module: **every file in the image is something an attacker can use and a scanner must report, so choose the smallest base that still runs the program, and then remove what the process does not need at run time.** You will compare two real images in the playground cluster, read what a process can reach from inside a container, and then restrict a pod so that it can reach less.

The module has two parts. **What Each Base Image Contains** describes Debian, Alpine, distroless and `scratch` images and compares BusyBox and a Python Alpine image in the cluster. **Measure What A Running Container Can Reach** reads the user, the filesystem and the Linux capabilities of a container and then restricts them with a `securityContext`.

## Learning objectives

After this module you can:

- Describe what Debian, Alpine, distroless and `scratch` base images contain and what each one cannot run.
- Explain the difference between the `musl` and `glibc` C libraries and why a static binary needs neither.
- Count the packages and programs in a running container and relate the count to attack surface.
- Read the user ID and the Linux capabilities of a process from inside a container.
- Restrict a pod with `runAsNonRoot`, a numeric `runAsUser`, `readOnlyRootFilesystem`, dropped capabilities and the `RuntimeDefault` seccomp profile.

## Before you start

You need Kubernetes basics: pods, namespaces, `kubectl get` and `kubectl exec`. You should know that a container image holds layers and that a tag is a name for an image.

The playground is a `kind` cluster running Kubernetes 1.35 with one control plane node and one worker node. Its content is the following:

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas that run `docker.io/library/python:3.13-alpine`, and the `shuttle` client pod that runs `docker.io/library/busybox:1.37.0` |
| `outpost` | The `drifter` client pod that runs `docker.io/library/busybox:1.37.0` |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
