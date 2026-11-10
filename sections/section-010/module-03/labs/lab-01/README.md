---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Pin An Image To The Digest The Node Reports

Read the digest that the node reports for the BusyBox image and start a pod that refers to the image by that digest.

The task and solution use a separate pinned kind cluster. Run `astrona test` on this folder: `testing/verify-start.sh` checks that every outcome fails on the starting state, then the reference solution is applied and every outcome must pass.
