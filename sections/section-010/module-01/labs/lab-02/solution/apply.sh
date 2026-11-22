#!/usr/bin/env bash
# Reference solution: a two-stage build with a scratch final stage and UID 65532.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-035-lab-010-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
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
