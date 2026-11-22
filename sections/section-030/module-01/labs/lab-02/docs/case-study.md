---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Starting Environment

The lab VM runs Docker, a container registry on `127.0.0.1:5000` and a one-node kubeadm cluster. The registry holds two unsigned images, named in `/srv/signing/image.txt` and `/srv/signing/unsigned.txt` with their digests. `/srv/signing` holds the training key pair (password `training-password`), and `/opt/astrona-live/other.pub` is the public key of an unrelated key pair.
