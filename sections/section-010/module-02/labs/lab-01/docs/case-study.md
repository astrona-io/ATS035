---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required pod does not exist.

Run a BusyBox pod as a numeric non-root user with a read-only root filesystem, no capabilities and the runtime default seccomp profile, and prove each setting from inside the container.
