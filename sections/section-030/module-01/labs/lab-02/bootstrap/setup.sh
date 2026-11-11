#!/usr/bin/env bash
set -euo pipefail
sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl python3 ca-certificates
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

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import json,pathlib,subprocess,sys,urllib.request
def run(args): return subprocess.run(args,text=True,capture_output=True,timeout=60)
def verify(key,reference): return run(['cosign','verify','--key',key,'--insecure-ignore-tlog=true','--allow-insecure-registry',reference])
def check(outcome):
    with urllib.request.urlopen('http://127.0.0.1:5000/v2/',timeout=5) as response:
        if response.status!=200: raise RuntimeError('The registry must remain available')
    assert run(['sha256sum','-c','/opt/astrona-live/keys.sha256']).returncode==0, 'Preserve both trust keys'
    image=pathlib.Path('/opt/astrona-live/image.txt').read_text().strip()
    unsigned=pathlib.Path('/opt/astrona-live/unsigned.txt').read_text().strip()
    assert pathlib.Path('/srv/signing/image.txt').read_text().strip()==image, 'Preserve the supplied image digest'
    accepted=verify('/srv/signing/training.pub',image)
    assert accepted.returncode==0, 'Sign the exact supplied image digest with the training key'
    signatures=json.loads(accepted.stdout)
    assert signatures and all(s['critical']['image']['docker-manifest-digest']==image.split('@')[1] for s in signatures), 'The verified claims must bind the image digest'
    if outcome=='trust-boundary':
        wrong=verify('/opt/astrona-live/other.pub',image)
        assert wrong.returncode!=0 and any(t in wrong.stderr.lower() for t in ('no matching signatures','signature verification','invalid signature','failed to verify signature')), 'Reject the signed image under an unrelated public key: '+wrong.stderr[-1800:]
        absent=verify('/srv/signing/training.pub',unsigned)
        assert absent.returncode!=0 and any(t in absent.stderr.lower() for t in ('no signatures','no matching signatures','no matching attestations','not found','manifest unknown')), 'Reject the unsigned image under the trusted key'
    elif outcome!='image-signature': raise RuntimeError('Unknown outcome')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
