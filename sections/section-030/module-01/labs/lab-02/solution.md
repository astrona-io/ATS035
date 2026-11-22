---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Sign And Verify An Immutable Image Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-030-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-030-01-02`. You are logged in as the `student` user. The VM runs Docker, a container registry and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Cosign and the registry. These commands change only the lab VM, not your own computer.

## Sign the digest

Cosign signs a digest, the SHA-256 hash that names the exact content of an image, and stores the signature next to the image in the registry. A tag such as `v1` can later point to other content, so the reference in `/srv/signing/image.txt` names the digest after `@`.

Read the reference, sign it with the training key, and verify it with the training public key:

```sh
image=$(cat /srv/signing/image.txt)
COSIGN_PASSWORD=training-password cosign sign --yes --use-signing-config=false --key /srv/signing/training.key --tlog-upload=false --allow-insecure-registry "$image"
cosign verify --key /srv/signing/training.pub --insecure-ignore-tlog=true --allow-insecure-registry "$image"
```

`--tlog-upload=false` and `--insecure-ignore-tlog=true` skip the public transparency log, which this VM cannot reach. The verification still checks the signature. Its JSON output has the field `critical.image.docker-manifest-digest`. Compare it with the digest after `@` in `/srv/signing/image.txt`; they must be the same.

## Check the trust boundary

A signature check is only useful when it also rejects what it must reject. Run it with the unrelated public key, then against the unsigned image:

```sh
cosign verify --key /opt/astrona-live/other.pub --insecure-ignore-tlog=true --allow-insecure-registry "$image"
unsigned=$(cat /srv/signing/unsigned.txt)
cosign verify --key /srv/signing/training.pub --insecure-ignore-tlog=true --allow-insecure-registry "$unsigned"
```

Both commands must fail with a signature error, not with a connection error. If you see a connection error, check that the registry answers with `curl --fail http://127.0.0.1:5000/v2/`, then run the trusted-key check again as a control.
