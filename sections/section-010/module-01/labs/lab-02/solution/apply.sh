#!/usr/bin/env bash
set -euo pipefail
sudo tee /srv/build/Dockerfile >/dev/null <<'DOCKERFILE'
FROM gcc:15.2.0 AS build
WORKDIR /src
COPY server.c .
RUN gcc -static -Os -s -o /server server.c
FROM scratch
COPY --from=build /server /server
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/server"]
DOCKERFILE
sudo docker build --network=none -t training-built:latest /srv/build
