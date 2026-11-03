---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Give A Service Account Registry Pull Access

Create a registry pull secret, attach it to a service account and run a pod that receives it.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
