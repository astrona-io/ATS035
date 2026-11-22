#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Starting state: Docker with alpine:3.18.0 in its image cache, Trivy v0.76.2
# and a Trivy database downloaded now to /var/cache/trivy-training. The
# grader keeps the database hashes in /opt/astrona-live; /srv/scan is empty.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-035-lab-040-02-02}"
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
  -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold docker.io curl python3 ca-certificates
sudo systemctl enable --now docker
case "$(uname -m)" in
 x86_64) arch=64bit; checksum=bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf ;;
 aarch64) arch=ARM64; checksum=ab9d51f86e6a5fb936f605faff6b593ac51bc378fff4d3e8b9d58358b9c367c3 ;;
 *) exit 2 ;;
esac
curl -fL --retry 3 --max-time 180 "https://github.com/aquasecurity/trivy/releases/download/v0.76.2/trivy_0.76.2_Linux-$arch.tar.gz" -o /tmp/trivy.tar.gz
printf '%s  /tmp/trivy.tar.gz\n' "$checksum" | sha256sum -c -
sudo tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy
sudo docker pull alpine:3.18.0
sudo install -d -m 0777 /srv/scan
sudo install -d /opt/astrona-live /var/cache/trivy-training
sudo trivy image --cache-dir /var/cache/trivy-training --download-db-only --no-progress
sudo sha256sum /var/cache/trivy-training/db/trivy.db /var/cache/trivy-training/db/metadata.json | sudo tee /opt/astrona-live/db.sha256 >/dev/null
