---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Starting Environment

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. Two more namespaces exist: `release-line`, which has no labels, and `supply-system`, which carries the label `training.astrona.io/supply-chain: exempt`. No admission policy exists.

Enforce an approved registry and a digest requirement together in one namespace while one system namespace stays exempt.
