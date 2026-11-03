---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Run A Hardened Minimal Web Server

Serve a page from a digest-pinned BusyBox image with a restricted security context, resource limits and a Service that a client pod can reach.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
