---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Pin An Image To The Digest The Node Reports

Read the digest that the node reports for the BusyBox image and start a pod that refers to the image by that digest.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
