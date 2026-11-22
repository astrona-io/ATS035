---
exam_objectives:
- Minimize base image footprint
---
# Build A Minimal Runtime Image Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-010-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-010-01-02`. You are logged in as the `student` user. The Docker daemon belongs to root, so run every `docker` command with `sudo`. These commands change only the lab VM, not your own computer.

## Look at the starting files

Read the current Dockerfile and the source before you change anything:

```sh
cat /srv/build/Dockerfile
cat /srv/build/server.c
```

The Dockerfile has one `FROM gcc:15.2.0` line, so the final image is the whole compiler image and the server runs as root. The source listens on port 8080 and answers `built-service`.

## Write the multi-stage Dockerfile

A multi-stage build uses one stage to compile the program and a second stage that holds only the result. Docker keeps only the last stage in the final image. `-static` links the C libraries into the program, so it can start in `scratch`, the empty base image that has no shell and no package manager. A numeric `USER` works without an `/etc/passwd` file.

Save this as `/srv/build/Dockerfile`:

```dockerfile
FROM gcc:15.2.0 AS build
WORKDIR /src
COPY server.c .
RUN gcc -static -Os -s -o /server server.c
FROM scratch
COPY --from=build /server /server
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/server"]
```

## Build and inspect the image

Build with networking turned off, the same way the grader does, and print the image size in bytes and the image user:

```sh
sudo docker build --network=none -t training-built:latest /srv/build
sudo docker image inspect training-built:latest --format '{{.Size}} {{.Config.User}}'
```

The size must be below 10485760 bytes (10 MiB), and the user must be `65532:65532`.

## Run it with restrictions

Start the image with a read-only root filesystem, no Linux capabilities and no new privileges, then send a request and list the files in the container:

```sh
sudo docker run -d --name built-server --read-only --cap-drop=ALL --security-opt=no-new-privileges -p 127.0.0.1:8080:8080 training-built:latest
curl --fail http://127.0.0.1:8080/
sudo docker export built-server | tar -tf -
sudo docker rm -f built-server
```

`curl` prints `built-service`. The file list has `server`, but no compiler, no shell and no `server.c`. The grader repeats these checks with its own build and its own container.
