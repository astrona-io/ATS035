---
exam_objectives:
- Minimize base image footprint
---
# Starting Environment

The lab VM runs Docker and a one-node kubeadm cluster. `/srv/build/server.c` is an HTTP server that answers `built-service` on port 8080. `/srv/build/Dockerfile` compiles it in `gcc:15.2.0` and runs it in that same image as root. Docker has `gcc:15.2.0` in its local image cache.
