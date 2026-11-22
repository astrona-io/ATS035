---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The lab VM runs Docker and a one-node kubeadm cluster. Docker has the old `alpine:3.18.0` image in its local image cache. Trivy is installed, and its vulnerability database in `/var/cache/trivy-training` was downloaded when the VM started. `/srv/scan` is empty.
