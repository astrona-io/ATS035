---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Summary

Static analysis reads manifests and images without running them. It finds risky declarations early and cheaply, and it cannot see run-time behaviour, new vulnerabilities or changes made after the scan. The input should be the rendered manifest that the cluster receives, because templates, overlays and admission change fields.

Kubesec scores a manifest. Its report groups findings into critical, advise and passed, each with a selector, a reason and points. A privileged container is critical, and settings such as a non-root user, a read-only root file system and dropped capabilities earn points. KubeLinter reports named checks, exits with a non-zero code on findings and takes checks from a configuration file. A single object can carry an `ignore-check.kube-linter.io/<check>` annotation with a reason.

Image scanning is a separate question. Trivy compares the packages in an image with vulnerability databases, so its result depends on the date and the digest. Trivy can also check manifests with `trivy config`. Pod Security Admission enforces the Pod Security Standards from a namespace label, and a server-side dry run of a label change shows which pods would fail.

A release decision joins manifest evidence, image evidence and cluster enforcement, and it records exceptions with a reason and an owner.

- A score is a ranking of declarations and not proof of safety.
- Scan the rendered manifest and the image digest that will run.
- Use `enforce` and not only `warn` when the cluster must reject pods.
- Record scanner version, date and digest with every result.

<!-- astrona:playground:destroy -->
