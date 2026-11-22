---
exam_objectives:
- Minimize base image footprint
---
# Choose An Image Pull Policy From What The Node Holds

Repair a pod that may not pull by pointing it at an image the node already holds, and make a Deployment ask the registry each time its container starts.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
