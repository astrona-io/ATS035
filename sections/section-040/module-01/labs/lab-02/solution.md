---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Lint A Live Deployment With KubeLinter Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-01-02" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Read the findings

KubeLinter checks the object it receives. Here it receives the live Deployment from the API server, so the report describes what the cluster actually stores, not a source file that may differ. First read the team configuration, so you know which checks run:

```sh
kubectl -n starfleet-035-040-01-02 get configmap lint-policy -o jsonpath='{.data.kube-linter\.yaml}'
```

The file sets `doNotAutoAddDefaults: true` and lists seven checks under `include`. Only those seven checks run. Now send the live Deployment to KubeLinter in the `linter` pod:

```sh
kubectl -n starfleet-035-040-01-02 get deployment lint-probe -o yaml |
  kubectl -n starfleet-035-040-01-02 exec -i linter -- /kube-linter lint --config /policy/kube-linter.yaml -
```

Each finding names the `lint-probe` Deployment, the check that failed and a remediation. Expect findings about the privileged container and privilege escalation, the root user, the writable root filesystem and the missing CPU and memory settings. The image already has a fixed tag, so `latest-tag` passes. The command ends with a non-zero exit code, which is what would stop a pipeline.

## Fix the Deployment and record the exception

All findings but one have a direct fix in the pod template. The `no-read-only-root-fs` finding stays: the application writes `/tmp/last-run` in its root filesystem, so the team records an exception on this one object with a reason and an owner. The `ignore-check.kube-linter.io/<check-name>` annotation tells KubeLinter to skip that one check for this object only. The configuration file still runs the check for every other object.

Save this as `deployment-lint-probe.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lint-probe
  namespace: starfleet-035-040-01-02
  annotations:
    ignore-check.kube-linter.io/no-read-only-root-fs: "the application writes /tmp/last-run; owner: platform team"
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
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
      containers:
      - name: app
        image: docker.io/library/busybox:1.37.0
        imagePullPolicy: IfNotPresent
        command:
        - sh
        - -c
        - while true; do date > /tmp/last-run; sleep 30; done
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 100m
            memory: 64Mi
```

Apply it:

```sh
kubectl apply -f deployment-lint-probe.yaml
```

Then check the result. The Deployment controller starts a new ReplicaSet with the new pod template and removes the old pod:

```sh
kubectl -n starfleet-035-040-01-02 rollout status deployment/lint-probe --timeout=180s
kubectl -n starfleet-035-040-01-02 exec deploy/lint-probe -- id -u
kubectl -n starfleet-035-040-01-02 exec deploy/lint-probe -- cat /tmp/last-run
```

The rollout command reports that the rollout finished. The process runs as user 10001, and `/tmp/last-run` holds the date that the application wrote. That write is the reason for the exception.

## Lint again

Run the same lint command on the live Deployment:

```sh
kubectl -n starfleet-035-040-01-02 get deployment lint-probe -o yaml |
  kubectl -n starfleet-035-040-01-02 exec -i linter -- /kube-linter lint --config /policy/kube-linter.yaml -
```

KubeLinter now reports that it found no lint errors, and the exit code is zero. The report is clean because every other finding was fixed and one check was skipped by a written exception, and a reviewer can tell the two apart by reading the annotation. A clean report still says nothing about the packages inside `busybox:1.37.0`; that needs an image scan.

After recording your result, remove the lab with `astrona destroy ats-035-lab-040-01-02`.

## Common pitfalls

> [!WARNING]
> - **Linting a local file instead of the live object.** The cluster may hold a different version. Pipe `kubectl get -o yaml` into the linter, or lint the rendered manifest that you apply.
> - **Silencing a finding by changing the configuration.** An `exclude` in the configuration file turns the check off for every object. Use the object annotation for one exception.
> - **Putting the annotation on the pod template only.** Record the exception in the Deployment `metadata`, where the grader and the reviewers look for it.
> - **An exception without an owner.** Write the reason and the owner in the annotation value, so someone can review it later.
