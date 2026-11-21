---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Summary

Everything in a container image is attack surface: every shell, package manager, library and leftover credential. A minimal image carries what the application needs at run time and nothing else, and the cluster refers to it by content and not by name.

## What you learned

An image is an OCI manifest that lists a config and a set of layers, and an image index chooses one manifest for each platform. A layer is permanent, so a file deleted by a later instruction stays in the earlier layer. A tag is a movable name. A digest is the SHA-256 hash of the manifest, so it always selects the same bytes. The `imageID` field in the pod status shows which content the container runtime resolved, and `crictl images --digests` on a node shows the same digests.

A multi-stage Dockerfile builds in one stage and copies only the result into a small final stage. Distroless images hold the files a program needs and no shell or package manager, and `scratch` holds nothing at all, which requires a static binary. Alpine is small but keeps a shell and `apk`. The final base still needs regular rebuilds, because a small image on an old base keeps the vulnerabilities of that base.

Dockerfile mistakes are visible in the text: a floating `latest` tag, unneeded packages, `ADD` where `COPY` is enough, a missing `USER`, and credentials passed with `COPY`, `ARG` or `ENV`. Hadolint and `trivy config` find many of them before a build. A secret mount (`RUN --mount=type=secret`) keeps a credential out of every layer. A `.dockerignore` file keeps files out of the build context.

In the cluster, `readOnlyRootFilesystem`, `runAsNonRoot` with a numeric user, dropped capabilities and the `RuntimeDefault` seccomp profile limit what the process can do. An ephemeral container (`kubectl debug`) brings debug tools to a pod whose image has none. `ErrImagePull` and `ImagePullBackOff` mean the node could not get the image, and the event message names the reason.

- Ship only what runs; build in a separate stage.
- Refer to an image by digest when exact content matters.
- Never put a credential in a layer; use a secret mount.
- Run as a numeric non-root user with a read-only root filesystem.



## Independent live assessment

Prepare with [Build And Inspect The Final Image](course-02a-build-and-inspect-the-final-image.md). [Build A Minimal Runtime Image](labs/lab-02/question.md) uses its own qemu environment. A fresh multi-stage build produces a small final filesystem without build tools; The built image serves HTTP as a non-root user with a read-only root filesystem.

<!-- astrona:playground:destroy -->
