---
draft: true
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Summary

An image policy needs two working halves: the cluster must pull approved images, and it must refuse everything else. Both halves have settings that can fail quietly.

## What you learned

A registry credential is a Secret of type `kubernetes.io/dockerconfigjson` with the key `.dockerconfigjson`. A pod lists Secrets in `imagePullSecrets`, and a ServiceAccount can list them too, because the ServiceAccount admission plugin copies the list into the pods that use the account. The kubelet presents the credentials to the registry host that matches the image reference. Base64 is an encoding and not encryption, so the credentials need a read-only registry account, narrow RBAC on Secrets and a small scope, and a node-level credential provider avoids long-lived Secrets.

ImagePolicyWebhook is an admission plugin that sends an `ImageReview` to an external backend. It is enabled with `--enable-admission-plugins`, and `--admission-control-config-file` points to an `AdmissionConfiguration` file that names a backend kubeconfig. The `defaultAllow` setting decides what happens when the backend cannot be reached. With `true` the plugin fails open, so a security control uses `false` and a backend with several replicas.

A check blocks a bad pod only when a binding exists, the binding uses `Deny`, the binding selects the namespace, and the check fails closed. `Audit` and `Warn` never reject a request. A removed namespace label exempts the namespace, so permission to edit namespace labels is part of the control. For webhooks, `failurePolicy: Fail` rejects requests when the service fails, `Ignore` admits them, and selectors can leave namespaces open. A request that must be rejected is the proper test of a control.

- Give each namespace the pull credentials it needs and nothing wider.
- Use `defaultAllow: false` and `failurePolicy: Fail` for security checks.
- Enforce with `Deny` and test with a request that must fail.
- Treat namespace labels and webhook selectors as part of the policy.

<!-- astrona:playground:destroy -->
