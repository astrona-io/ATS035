#!/usr/bin/env bash
# Runs inside the lab VM from /opt/astrona-lab after vm/install.sh built the cluster.
# Starting state: Docker with a registry on 127.0.0.1:5000 that holds the
# unsigned images scout:v1 and unsigned:v1, Cosign v3.1.4, the training key
# pair in /srv/signing and an unrelated key pair in /opt/astrona-live. The
# grader keeps its own copies of the image references and key hashes there.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-035-lab-030-01-02}"
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
 x86_64) arch=amd64; checksum=424e2c97d0b45fd7a6b608a87f090f35633f4c23ece5f092d48bba11aaf4bbfa ;;
 aarch64) arch=arm64; checksum=ade83b7aac62e131cacfe96d958948b2150cc9efec46a570a2649b8e27dedad2 ;;
 *) exit 2 ;;
esac
curl -fL --retry 3 --max-time 180 "https://github.com/sigstore/cosign/releases/download/v3.1.4/cosign-linux-$arch" -o /tmp/cosign
printf '%s  /tmp/cosign\n' "$checksum" | sha256sum -c -
sudo install -m 0755 /tmp/cosign /usr/local/bin/cosign
sudo docker run -d --name registry -p 127.0.0.1:5000:5000 registry:2.8.3
for attempt in $(seq 1 30); do curl -fsS http://127.0.0.1:5000/v2/ >/dev/null && break; sleep 1; done
sudo docker pull busybox:1.37.0
sudo docker tag busybox:1.37.0 localhost:5000/scout:v1
sudo docker push localhost:5000/scout:v1
sudo docker pull alpine:3.18.0
sudo docker tag alpine:3.18.0 localhost:5000/unsigned:v1
sudo docker push localhost:5000/unsigned:v1
sudo install -d -m 0777 /srv/signing
sudo install -d /opt/astrona-live
sudo env COSIGN_PASSWORD=training-password cosign generate-key-pair --output-key-prefix /srv/signing/training
sudo env COSIGN_PASSWORD=training-password cosign generate-key-pair --output-key-prefix /opt/astrona-live/other
sudo chmod 0644 /srv/signing/training.key
sudo sha256sum /srv/signing/training.pub /opt/astrona-live/other.pub | sudo tee /opt/astrona-live/keys.sha256 >/dev/null
sudo docker image inspect localhost:5000/scout:v1 --format '{{index .RepoDigests 0}}' | sudo tee /srv/signing/image.txt >/dev/null
sudo docker image inspect localhost:5000/unsigned:v1 --format '{{index .RepoDigests 0}}' | sudo tee /srv/signing/unsigned.txt >/dev/null
# Read the digest actually stored by the local registry after its push.
sudo python3 - <<'REFS'
import pathlib,urllib.request
for repository,file in [('scout','image'),('unsigned','unsigned')]:
 request=urllib.request.Request('http://localhost:5000/v2/'+repository+'/manifests/v1',headers={'Accept':'application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json'})
 with urllib.request.urlopen(request) as response: digest=response.headers['Docker-Content-Digest']
 assert digest and digest.startswith('sha256:')
 pathlib.Path('/srv/signing/'+file+'.txt').write_text('localhost:5000/'+repository+'@'+digest+'\n')
REFS
sudo cp /srv/signing/image.txt /opt/astrona-live/image.txt
sudo cp /srv/signing/unsigned.txt /opt/astrona-live/unsigned.txt
