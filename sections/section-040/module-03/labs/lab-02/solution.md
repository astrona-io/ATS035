---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce Baseline And Warn On Restricted With Pod Security Admission Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-02" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Preview and set the labels

Pod Security Admission (PSA) is the admission controller in the API server that checks each new pod against a Pod Security Standard. A namespace label picks the standard for each mode: `enforce` rejects a pod that violates it, `warn` admits the pod and returns a warning to the client, and `audit` admits the pod and adds an annotation to the audit log event. One namespace can use a different standard in each mode. Here `enforce` uses `baseline`, which blocks known privilege escalations such as a privileged container, while `warn` and `audit` use the stricter `restricted` standard to show what still has to change.

First preview the enforce label with a server-side dry run. The API server checks the pods that already run, prints a warning, and does not change the namespace:

```sh
kubectl label --dry-run=server --overwrite namespace hangar-035-040-03-02 pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/enforce-version=v1.35
```

The warning says that existing pods violate the new enforce level `baseline:v1.35` and names `legacy-scanner` with the `privileged` field. PSA checks a pod only when it is created or updated, so this pod keeps running after the label is set.

Save this as `namespace-hangar.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hangar-035-040-03-02
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: v1.35
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.35
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.35
```

Apply it:

```sh
kubectl apply -f namespace-hangar.yaml
```

Then check the result:

```sh
kubectl get namespace hangar-035-040-03-02 --show-labels
kubectl -n hangar-035-040-03-02 get pod legacy-scanner
```

The namespace shows the six PSA labels, and `legacy-scanner` is still `Running`. The API server printed the same warning about existing pods when it applied the label. The `-version` labels pin each mode to the standard as defined in Kubernetes 1.35, so a cluster upgrade does not change the result until you change the labels.

## Create a workload that meets baseline only

A pod with no `securityContext` meets `baseline`: it is not privileged and uses no host namespaces. It does not meet `restricted`, which also needs a non-root user, no privilege escalation, dropped capabilities and a seccomp profile. For a Deployment, `warn` and `audit` also check the pod template, so the warning appears when you apply the Deployment.

Save this as `deployment-cargo-loader.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cargo-loader
  namespace: hangar-035-040-03-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cargo-loader
  template:
    metadata:
      labels:
        app: cargo-loader
    spec:
      containers:
      - name: loader
        image: docker.io/library/busybox:1.37.0
        imagePullPolicy: IfNotPresent
        command: ["sh", "-c", "while true; do sleep 3600; done"]
```

Apply it:

```sh
kubectl apply -f deployment-cargo-loader.yaml
```

kubectl prints a warning that the Deployment would violate PodSecurity `restricted:v1.35`, followed by the fields that fail. The API server still creates the Deployment. Then check the result:

```sh
kubectl -n hangar-035-040-03-02 rollout status deployment/cargo-loader --timeout=180s
```

The rollout finishes, because `enforce` checks the pod against `baseline` and the pod meets it.

## Show that baseline is enforced

A privileged pod violates `baseline`, so `enforce` must reject it. Save this as `pod-privileged-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: privileged-check
  namespace: hangar-035-040-03-02
spec:
  restartPolicy: Never
  containers:
  - name: check
    image: docker.io/library/busybox:1.37.0
    imagePullPolicy: IfNotPresent
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      privileged: true
```

Send it as a server-side dry run, so the API server runs admission but stores nothing:

```sh
kubectl apply --dry-run=server -f pod-privileged-check.yaml
```

The API server rejects the request. The error says that the pod violates PodSecurity `baseline:v1.35` and names the `privileged` field of the container `check`. The same spec as `legacy-scanner` is now rejected, while `legacy-scanner` itself still runs. That pod will be rejected too the next time it is recreated, so the team must fix it before it restarts.

After recording your result, remove the lab with `astrona destroy ats-035-lab-040-03-02`.

## Common pitfalls

> [!WARNING]
> - **Expecting a label to stop running pods.** PSA checks pods on create and update only. Use the dry run on the label to find pods that will fail when they are recreated.
> - **Leaving out the `-version` labels.** A mode without one uses `latest`, and the messages then show `latest` instead of `v1.35`. Pin each mode on its own.
> - **Reading the Deployment warning as a rejection.** `warn` admits the Deployment. Only `enforce` rejects, and it rejects pods, not the Deployment.
> - **Creating the test pod for real.** Use `--dry-run=server`, so admission runs and nothing is stored.
