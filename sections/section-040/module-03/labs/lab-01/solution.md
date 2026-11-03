---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Enforce The Restricted Pod Security Standard Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-01" || exit 1
node_name="astro-ats-035-lab-040-03-01-control-plane"
worker_name="astro-ats-035-lab-040-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The namespace `hangar` exists without Pod Security Admission labels, so every pod is accepted there.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Label namespace `hangar` with `pod-security.kubernetes.io/enforce=restricted`, `pod-security.kubernetes.io/enforce-version=v1.35`, `pod-security.kubernetes.io/warn=restricted` and `pod-security.kubernetes.io/audit=restricted`. Create pod `restricted-reader` in `hangar` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, the `RuntimeDefault` seccomp profile, `allowPrivilegeEscalation: false` and all capabilities dropped. It must be Ready. A pod that sets `privileged: true` must be rejected in `hangar`, and you must not create it.

Save this as `namespace-hangar.yaml`. The namespace carries the Pod Security Admission labels, and the pod meets the `restricted` standard:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hangar
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
---
apiVersion: v1
kind: Pod
metadata:
  name: restricted-reader
  namespace: hangar
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
```

Apply it:

```sh
kubectl apply -f namespace-hangar.yaml
```

Save this as `pod-unrestricted-reader.yaml`. It sets `privileged: true`, which the `restricted` standard does not allow:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: unrestricted-reader
  namespace: hangar
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      privileged: true
```

Try to apply it. The command must fail:

```sh
kubectl apply -f pod-unrestricted-reader.yaml
```

## Verify The Result

Wait for the compliant pod, then read the namespace labels. The error from the previous command names the `restricted` level and the rejected fields.

```sh
kubectl -n hangar wait --for=condition=Ready pod/restricted-reader --timeout=180s
kubectl get namespace hangar --show-labels
```

Label a namespace to enforce the restricted Pod Security Standard and run one compliant pod while an unrestricted pod is rejected. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required result. A matching field alone does not establish that a controller reconciled it.

After recording your result, remove the independent environment with `astrona destroy ats-035-lab-040-03-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
