---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `gated-images-035-030-03-01` has a ServiceAccount named `deployer`, a ValidatingAdmissionPolicy named `gated-registry` and a binding of the same name. The binding has the validation action `Audit` only, so no pod is rejected yet.

Change an audit-only registry binding to enforcement and attach registry pull credentials to a ServiceAccount.
