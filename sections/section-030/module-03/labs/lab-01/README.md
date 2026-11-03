---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Enforce A Registry Policy And Attach Pull Credentials

Change an audit-only registry binding to enforcement and attach registry pull credentials to a ServiceAccount.

The task and solution use a separate pinned kind cluster. Run `testing/smoke.sh` with its private kubeconfig to verify initial rejection and reference success. Static validation is not live evidence. Runtime verification remains pending.
