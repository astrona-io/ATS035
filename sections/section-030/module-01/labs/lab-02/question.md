---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Sign And Verify An Immutable Image

Allow about 15 minutes for the tasks.

A release process must accept the `scout` image only when the training key signed its exact digest. Prove that the signature check also rejects the wrong key and an image that nobody signed.

## Starting state

Docker runs a container registry on `127.0.0.1:5000`. A registry is a server that stores images and their signatures. It holds two unsigned images. `/srv/signing/image.txt` holds the `scout` image reference with its digest, and `/srv/signing/unsigned.txt` holds the reference of the other image. Cosign, the command-line tool that signs and verifies images, is installed.

`/srv/signing/training.key` and `/srv/signing/training.pub` are the training key pair. The password of the private key is `training-password`. `/opt/astrona-live/other.pub` is the public key of an unrelated key pair.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-030-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-030-01-02`. You are logged in as the `student` user. The VM runs Docker, a container registry and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Cosign and the registry. These commands change only the lab VM, not your own computer.

## Tasks

1. Sign the exact digest in `/srv/signing/image.txt` with `/srv/signing/training.key`. Store the signature in the local registry, then verify it with `/srv/signing/training.pub`.
2. Show that verification of the same digest fails with `/opt/astrona-live/other.pub`, and that verification of the image in `/srv/signing/unsigned.txt` fails with the training public key. Check that the digest in the accepted signature matches the digest in `/srv/signing/image.txt`.

## Constraints

Do not change the images, the reference files or the key pairs. Use `--allow-insecure-registry` only for this loopback HTTP registry. Turn off the transparency-log upload when you sign, and pass `--insecure-ignore-tlog=true` when you verify. Do not turn off the signature or digest checks.

## How the answer is checked

The grader checks that the registry answers and that the key files are unchanged. It verifies the signature of the `scout` digest with the training public key and compares the digest in the signature. Then it runs the verification with the unrelated key and against the unsigned image, and both must fail with a signature error.
