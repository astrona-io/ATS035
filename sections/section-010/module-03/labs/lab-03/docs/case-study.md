---
exam_objectives:
- Minimize base image footprint
---
# Starting Environment

The namespace `starfleet-035-010-03-03` has only the `shuttle` client pod, which runs `docker.io/library/busybox:1.37.0`. The namespace `outpost-035-010-03-03` has the `drifter` client pod. There is no web server and no Service yet.

Run a minimal BusyBox web server as a Deployment pinned to a digest, give it CPU and memory requests and a 64Mi memory limit, and reach it from the `shuttle` pod through a Service on port 80.
