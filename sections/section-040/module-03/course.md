---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce Workload Standards With Pod Security Admission

Static analysis finds risky settings before a release, but it cannot stop a person who applies a manifest directly to the cluster. Pod Security Admission (PSA) closes that gap. It is a built-in check in the Kubernetes API server that compares every new pod with a named standard and rejects, warns about or records the pods that do not meet it.

This module teaches the three Pod Security Standards, how a namespace label chooses a standard and a mode, how to preview a label change with a server-side dry run, how the `restricted` standard maps to `securityContext` fields, and where exemptions come from.

## Learning objectives

After this module you can:

- Name the three Pod Security Standards and say what each one forbids.
- Set the `enforce`, `audit` and `warn` modes and a version on a namespace with labels.
- Preview a label change with `--dry-run=server` and explain what it lists.
- Write a pod that passes the `restricted` standard and read the error of a pod that fails it.
- Explain what PSA does not check and who can exempt a user, a namespace or a runtime class.

## Before you start

You need Kubernetes basics: pods, namespaces, labels, `kubectl apply` and the `securityContext` field of a pod. You do not need any tool on your own machine except `kubectl`.

The playground cluster is a `kind` cluster running Kubernetes 1.35. PSA is enabled by default in this version.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment and the `shuttle` pod |
| `outpost` | The `drifter` client pod |
| `hangar` | An empty namespace without Pod Security Admission labels |

## Reading order

1. The Pod Security Standards
2. Namespace labels, modes and versions
3. Meeting the restricted standard, exemptions and limits
4. Summary

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
