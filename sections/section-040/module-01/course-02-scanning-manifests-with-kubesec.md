---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Scanning Manifests With Kubesec

Kubesec is a security risk analysis tool for Kubernetes resources. It reads a manifest, gives it a numeric score and lists the fields that raise or lower that score. This part scans a deliberately weak Deployment, reads each field of the report and fixes the findings, so that you can read a Kubesec report in the exam without guessing.

## How Kubesec scores

Kubesec tests a pod specification against a fixed set of rules. Each rule has a selector, which is the path of the field, and points. The report has three groups:

- **critical**: settings that make the pod dangerous, for example `containers[] .securityContext .privileged == true`. These lower the score and can give a negative total.
- **advise**: settings that are not present but would improve security, for example `containers[] .securityContext .readOnlyRootFilesystem == true`, `runAsNonRoot == true` and `capabilities .drop`. Each adds points when you set it.
- **passed**: rules that the manifest already satisfies.

Each entry has an `id`, a `selector`, a `reason` and `points`. The top-level `score` is the sum. A higher score means fewer declared risks. Kubesec supports Pods, Deployments, StatefulSets and DaemonSets. The score is a ranking of declarations, and a high score does not show that the application is safe.

## Scan a weak Deployment

The command runs on your machine. Install Kubesec first, or run it from its container image. Save this as `deployment-weak-probe.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weak-probe
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: weak-probe
  template:
    metadata:
      labels:
        app: weak-probe
    spec:
      containers:
        - name: app
          image: docker.io/library/busybox:1.37.0
          command: ["sh", "-c", "sleep 3600"]
          securityContext:
            privileged: true
```

Scan the file:

```sh
kubesec scan deployment-weak-probe.yaml
```

Kubesec prints a JSON array with one object for the resource. Read these fields in order: `valid` tells whether Kubesec could parse the resource, `score` is the total, `scoring.critical` lists the privileged finding, and `scoring.advise` lists the missing hardening settings. The `jq` tool helps you read long reports:

```sh
kubesec scan deployment-weak-probe.yaml | jq '.[0] | {score, critical: [.scoring.critical[]?.selector], advise: [.scoring.advise[]?.selector]}'
```

The result is an object with the score and two lists of selectors. The privileged selector appears in the critical list. Your Kubesec version may add or rename rules, so read the output of your version rather than relying on a fixed list.

## Fix the findings and scan again

Save this as `deployment-fixed-probe.yaml`. It removes `privileged`, runs as a non-root user, blocks privilege escalation, drops all capabilities and makes the root file system read-only:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fixed-probe
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fixed-probe
  template:
    metadata:
      labels:
        app: fixed-probe
    spec:
      containers:
        - name: app
          image: docker.io/library/busybox:1.37.0
          command: ["sh", "-c", "sleep 3600"]
          securityContext:
            runAsNonRoot: true
            runAsUser: 10001
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
```

Scan it:

```sh
kubesec scan deployment-fixed-probe.yaml | jq '.[0] | {score, critical: [.scoring.critical[]?.selector], advise: [.scoring.advise[]?.selector]}'
```

The critical list is empty, the score is higher than before and the advise list is shorter. Remaining advice usually concerns resource limits, a seccomp profile or a service account setting. Compare the two scores yourself; the exact numbers depend on the Kubesec version.

## Use the score in a gate

A pipeline can fail a build when Kubesec reports a critical finding or a score below an agreed minimum. Parse the JSON with `jq` and exit with a non-zero code. Pick the minimum by policy, and record exceptions with an owner. Kubesec also runs as an HTTP service, which lets other tools post a manifest and get the JSON back, but the file-based scan above is enough for a pipeline.

You now know how Kubesec groups its findings, how to read selectors and points, and how to turn a report into a gate. Kubesec focuses on security fields. The next part uses KubeLinter, which checks security and also correctness and operations settings.

## Common pitfalls

> [!WARNING]
> - **Chasing the score.** A high score with an outdated image is still risky. Read the critical list first.
> - **Scanning only Pods.** Scan workload kinds such as Deployments, whose pod template holds the settings.
> - **Assuming fixed rule numbers.** Rules and points differ between versions. Read the report of your version.
> - **Applying a fix that breaks the app.** A read-only root file system needs writable volumes for temporary paths. Test the workload after hardening.
