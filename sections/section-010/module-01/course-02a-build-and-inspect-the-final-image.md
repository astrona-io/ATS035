---
draft: true
---
# Build And Inspect The Final Image

A multi-stage Dockerfile separates tools needed to compile an application from files needed to run it. Removing a compiler in a later layer of one stage does not remove its bytes from earlier layers. Copying the compiled output into a new `scratch` stage gives the final image a filesystem containing only the selected artifact.

This independent VM provides a small C HTTP server and a cached compiler image. The task is image construction; the source is fixed. Run all commands in that VM.

<!-- astrona:playground:renew -->

Inspect the starting files:

```sh
cat /srv/build/Dockerfile
cat /srv/build/server.c
```

Save this structure as `/srv/build/Dockerfile`:

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

`-static` links the runtime libraries into the executable, so it can start without a separate dynamic loader. `scratch` has no shell or package manager. A numeric user avoids requiring an `/etc/passwd` entry. The application listens on 8080, which does not require a privileged-port capability.

Build and inspect the result:

```sh
sudo docker build --network=none -t training-built:latest /srv/build
sudo docker image inspect training-built:latest --format '{{.Size}} {{.Config.User}}'
```

Start it under runtime restrictions and make a real request:

```sh
sudo docker run -d --name built-server --read-only --cap-drop=ALL --security-opt=no-new-privileges -p 127.0.0.1:8080:8080 training-built:latest
curl --fail http://127.0.0.1:8080/
sudo docker export built-server | tar -tf -
sudo docker rm -f built-server
```

The response should be `built-service`. The exported filesystem should contain `/server` without the compiler, source or shell. Check both the artifact and its behavior: a small image that cannot start is not a successful build.

## Common pitfalls

> [!WARNING]
> `USER` in the build stage does not automatically apply to a later stage. Set it in the final stage and test the running process. A minimal filesystem reduces installed components; it does not establish that the remaining binary is free of vulnerabilities.
