---
exam_objectives:
- Minimize base image footprint
---
# Run A Pinned Web Server With A Resource Budget And A Service

Run a minimal BusyBox web server as a Deployment pinned to a digest, give it CPU and memory requests and a 64Mi memory limit, and reach it from the `shuttle` pod through a Service on port 80.

The task and solution use a separate pinned kind cluster. The node pulls BusyBox from Docker Hub, so the `shuttle` pod reports a registry digest that the Deployment pins. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
