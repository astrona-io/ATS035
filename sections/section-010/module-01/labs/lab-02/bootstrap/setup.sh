#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Starting state: Docker with the cached gcc:15.2.0 image, the HTTP server
# source in /srv/build/server.c and a one-stage Dockerfile that keeps the
# compiler and runs as root. /opt/astrona-live/server.c is the grader's copy
# of the source.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-035-lab-010-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
# cloud-init can still hold the package lock right after the VM starts.
sudo cloud-init status --wait >/dev/null || true
sudo apt-get update -qq
# The cluster already runs on the containerd package. Hold its version and
# keep its configuration, so installing Docker does not restart the cluster.
sudo apt-mark hold containerd >/dev/null
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold docker.io curl python3
sudo systemctl enable --now docker
sudo docker pull gcc:15.2.0
sudo install -d -m 0777 /srv/build
sudo install -d /opt/astrona-live
sudo tee /srv/build/server.c >/dev/null <<'SOURCE'
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <string.h>
int main(void) {
 int fd=socket(AF_INET,SOCK_STREAM,0), one=1;
 setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
 struct sockaddr_in addr={.sin_family=AF_INET,.sin_port=htons(8080),.sin_addr.s_addr=INADDR_ANY};
 if(bind(fd,(struct sockaddr*)&addr,sizeof(addr)) || listen(fd,16)) return 1;
 for(;;) { int client=accept(fd,0,0); if(client<0) continue;
  char request[2048]; read(client,request,sizeof(request));
  const char *reply="HTTP/1.1 200 OK\r\nContent-Length: 14\r\nConnection: close\r\n\r\nbuilt-service\n";
  write(client,reply,strlen(reply)); close(client);
 }
}
SOURCE
sudo cp /srv/build/server.c /opt/astrona-live/server.c
sudo tee /srv/build/Dockerfile >/dev/null <<'DOCKERFILE'
FROM gcc:15.2.0
WORKDIR /src
COPY server.c .
RUN gcc -static -Os -s -o /server server.c
ENTRYPOINT ["/server"]
DOCKERFILE
sudo chmod 0666 /srv/build/Dockerfile

