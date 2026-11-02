---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Linting Manifests With KubeLinter

KubeLinter is a static analysis tool from StackRox that checks Kubernetes YAML files and Helm charts against a list of named checks. Unlike a single score, it reports each failed check with the object, the check name and a remediation hint. It also supports a configuration file and a per-object exception. This part runs KubeLinter, lists its checks, selects the ones a team needs and records one justified exception.

## Checks, findings and exit code

A KubeLinter **check** has a name such as `privileged-container`, `run-as-non-root`, `no-read-only-root-fs`, `privilege-escalation-container`, `latest-tag`, `unset-cpu-requirements` or `unset-memory-requirements`. A **finding** is one failed check on one object. The command exits with a non-zero code when it reports findings, which makes it usable as a pipeline gate. List the checks of your version:

<!-- astrona:playground:renew -->

```sh
kube-linter checks list
```

The list shows each check name, its description and whether it is enabled by default. Some checks are on by default and others are off, so the default result differs from a run with all checks.

## Lint a manifest

Save this as `deployment-lint-probe.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lint-probe
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lint-probe
  template:
    metadata:
      labels:
        app: lint-probe
    spec:
      containers:
        - name: app
          image: docker.io/library/busybox:latest
          command: ["sh", "-c", "sleep 3600"]
          securityContext:
            privileged: true
```

Lint it:

```sh
kube-linter lint deployment-lint-probe.yaml
```

Each finding names the file, the object and the check, and gives a message and a remediation. For this file expect findings about the privileged container, the `latest` tag and missing settings such as a non-root user or resource requests. The exit code is not zero. You can also lint a stream from another tool, for example the rendered output of Kustomize:

```sh
kubectl kustomize ./overlay | kube-linter lint -
```

## Choose checks with a configuration file

A team selects checks in a configuration file. Save this as `.kube-linter.yaml`. It turns on all built-in checks and then excludes one check by name:

```yaml
checks:
  addAllBuiltIn: true
  exclude:
    - unset-cpu-requirements
```

Run the linter with it:

```sh
kube-linter lint --config .kube-linter.yaml deployment-lint-probe.yaml
```

The report now contains the extra built-in checks and omits the excluded one. An exclusion in the configuration file applies to every object, so use it for a rule that the team has decided not to apply at all.

## Record an exception on one object

For a single object, add an annotation in the form `ignore-check.kube-linter.io/<check-name>` with a reason as its value. Add this to the Deployment metadata:

```yaml
metadata:
  name: lint-probe
  namespace: starfleet
  annotations:
    ignore-check.kube-linter.io/no-read-only-root-fs: "the application writes cache files; owner: platform team"
```

Run the lint again. The `no-read-only-root-fs` finding disappears for this object only, and the reason stays in the manifest where reviewers can read it. An exception without a reason is a silent hole, so require a reason and an owner.

You now know how KubeLinter names its checks, how the exit code gates a pipeline, how to select checks and how to record a scoped exception. Manifest tools still say nothing about the packages inside the image. The next part adds an image scan and the cluster's own enforcement.

## Common pitfalls

> [!WARNING]
> - **Ignoring the exit code.** A pipeline that does not fail on findings does not gate anything.
> - **Excluding a check globally to silence one object.** Use the object annotation for one-off exceptions.
> - **Exceptions without reasons.** Require a reason and an owner in the annotation.
> - **Linting source templates only.** Lint the rendered output, which is what the cluster receives.
