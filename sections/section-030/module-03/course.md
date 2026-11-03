---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# ImagePullSecrets, ImagePolicyWebhook And Admission Failure Modes

An image policy has two sides. The cluster must be able to pull approved images from a private registry, which needs credentials. The cluster must also refuse images that are not approved, which needs an admission check that keeps working when parts of it fail. This module teaches both sides: how pull credentials are stored and attached, how the ImagePolicyWebhook admission plugin is configured on the API server, and how a check can look active while it protects nothing.

Keep one sentence in mind for this module: **a control that fails open, or that is only set to audit, is a log entry and not a barrier.** You will create an image pull secret and attach it to a ServiceAccount, read the admission plugin settings of the playground control plane, and switch a binding between `Audit`, `Warn` and `Deny` while exempting and un-exempting a namespace.

The module has three parts. **Pull Credentials For Private Registries** covers Secrets of type `kubernetes.io/dockerconfigjson`, the `imagePullSecrets` field and ServiceAccounts. **The ImagePolicyWebhook Admission Plugin** explains its configuration files and the `defaultAllow` setting. **Admission Failure Modes And Exemptions** compares `failurePolicy`, validation actions and namespace selectors, and shows how each can disable a check.

## Learning objectives

After this module you can:

- Create a docker-registry Secret and attach it to a pod or to a ServiceAccount, and explain how the kubelet uses it.
- Explain the risks of image pull secrets and name safer options.
- Describe the admission configuration file, the backend kubeconfig and the settings of ImagePolicyWebhook, including `defaultAllow`.
- Explain what `failurePolicy: Fail` and `Ignore` decide for a webhook and for a ValidatingAdmissionPolicy.
- Find a check that is audit-only, fail-open or exempted, and repair it.

## Before you start

You need `kubectl`, the idea of a ServiceAccount, and a basic ValidatingAdmissionPolicy with a binding. The commands run against the playground cluster, a `kind` cluster running Kubernetes 1.35 with one control plane node and one worker node.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment with two replicas, and the `shuttle` client pod |
| `outpost` | The `drifter` client pod |
| `gated-images` | A ServiceAccount named `deployer`, a registry policy named `gated-registry` and a binding that only audits |

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
