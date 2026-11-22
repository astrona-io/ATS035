---
exam_objectives:
- Minimize base image footprint
---
# Compare Base Images And Move A Workload To The Smaller One

Read what the Alpine based probe image contains, then move a shell-only workload from that image to the smaller BusyBox image and show that it still works.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
