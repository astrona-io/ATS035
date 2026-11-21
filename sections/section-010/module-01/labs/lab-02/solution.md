---
draft: true
---
# Solution

Use this `/srv/build/Dockerfile`:

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

Build and run the restricted container using the preparation lesson commands. Inspect its filesystem and verify the live HTTP response.
