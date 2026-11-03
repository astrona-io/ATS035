---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Summary

Pod Security Admission checks the specification of every new or updated pod against one of three Pod Security Standards. The `privileged` level has no limits, `baseline` blocks the known paths to privilege escalation, and `restricted` adds non-root users, a seccomp profile, dropped capabilities and no privilege escalation. PSA reads only the pod specification, so it does not scan images and does not require a read-only root file system.

A namespace chooses the standard with labels of the form `pod-security.kubernetes.io/<mode>`. The `enforce` mode rejects a pod, `audit` records a violation in the audit log, and `warn` returns a warning to the client. A `<mode>-version` label pins the standard to a Kubernetes minor version, and `latest` follows the cluster. Changing a label does not remove running pods, and for a Deployment the check applies to the pod, so a failing rollout shows up in the ReplicaSet events.

A server-side dry run of a label change lists the existing pods that would violate the new level and changes nothing. A safe rollout previews with the dry run, sets `warn` and `audit` first, fixes the workloads, and then sets `enforce`.

Exemptions for users, runtime classes and namespaces are set in the API server admission configuration, not by namespace owners. PSA complements static analysis and image scanning: it enforces a minimum on the cluster, and the other tools find issues earlier or outside its reach.

- Preview a stricter level with `--dry-run=server` before you enforce it.
- Pin the version label and update it on purpose.
- Fix every field in the error message, not only the first one.
- Review exemptions, because they bypass the standard.

<!-- astrona:playground:destroy -->
