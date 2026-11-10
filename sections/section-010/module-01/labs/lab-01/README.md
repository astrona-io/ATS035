---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Serve Content With A Minimal Runtime

Select an image providing only the required HTTP process and verify its running contents.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
