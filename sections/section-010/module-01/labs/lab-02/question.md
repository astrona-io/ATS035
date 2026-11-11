---
draft: true
---
# Build A Minimal Runtime Image

Solve this question on: `terminal`

In this independent Ubuntu VM, `/srv/build/server.c` is a supplied HTTP server. The current Dockerfile keeps the compiler in its final image and runs as root. The compiler image is already cached.

Allow about 15 minutes for the tasks.

## Tasks

1. Rewrite `/srv/build/Dockerfile` as a multi-stage build. Compile the supplied source with `gcc -static -Os -s`, copy only `/server` into a `scratch` final stage, and keep the final image below 10 MiB.
2. Set UID and GID 65532, preserve `/server` as the entrypoint and port 8080, then build and run the image with a read-only root filesystem, no capabilities and no new privileges. Verify its HTTP response.

## Constraints

Keep the supplied source unchanged. Builds must work with networking disabled using cached `gcc:15.2.0`. Do not include a compiler, shell or source file in the final filesystem. The prebuilt compiler image is a lab dependency, not the artifact being assessed.

## How the answer is checked

The grader rebuilds the Dockerfile without cache or build networking, inspects the final filesystem and size, then starts the result with the required restrictions. It checks the live process UID and HTTP response.
