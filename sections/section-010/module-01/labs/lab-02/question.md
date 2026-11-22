---
exam_objectives:
- Minimize base image footprint
---
# Build A Minimal Runtime Image

Allow about 15 minutes for the tasks.

A small HTTP server must ship in an image that holds only the compiled program. The current Dockerfile keeps the whole compiler in the final image and runs the server as root.

## Starting state

`/srv/build/server.c` is the source of an HTTP server that listens on port 8080 and answers `built-service`. `/srv/build/Dockerfile` has one stage: it compiles the source in the `gcc:15.2.0` image and runs the result there, as root. Docker already has `gcc:15.2.0` in its local image cache.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-010-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-010-01-02`. You are logged in as the `student` user. The VM runs Docker and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Docker. The Docker daemon belongs to root, so run every `docker` command with `sudo`. These commands change only the lab VM, not your own computer.

## Tasks

1. Rewrite `/srv/build/Dockerfile` as a multi-stage build. Compile the source with `gcc -static -Os -s`, copy only `/server` into a `scratch` final stage, and keep the final image below 10 MiB.
2. Set the user to UID and GID 65532 and keep `/server` as the entrypoint and port 8080. Build the image, then run it with a read-only root filesystem, no Linux capabilities and no new privileges, and check its HTTP response.

## Constraints

Do not change `/srv/build/server.c`. The build must work with networking turned off, using the cached `gcc:15.2.0` image. The final filesystem must not contain a compiler, a shell or a source file.

## How the answer is checked

The grader builds `/srv/build/Dockerfile` again, without the build cache and with `--network=none`. It checks the image size, the image user and the files in the final filesystem. Then it starts a container with `--read-only`, `--cap-drop=ALL` and `--security-opt=no-new-privileges`, sends an HTTP request and reads the UID of the running process.
