---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The `shuttle` pod runs BusyBox by tag. The required workload does not exist.

Serve a page from a digest-pinned BusyBox image with a restricted security context, resource limits and a Service that a client pod can reach.
