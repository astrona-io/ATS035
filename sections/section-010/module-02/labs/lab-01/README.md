---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Run A Pod With A Restricted Security Context

Run a BusyBox pod as a numeric non-root user with a read-only root filesystem, no capabilities and the runtime default seccomp profile, and prove each setting from inside the container.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
