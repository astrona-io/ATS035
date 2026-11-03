---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Meeting The Restricted Standard, Exemptions And Limits

Most pods fail `restricted` for the same few reasons, and the error message lists them. A person who can read the message and map it to `securityContext` fields can fix a pod in a few minutes. This part writes a pod that passes, reads the message of one that fails, and states what PSA leaves to other controls.

## From the standard to securityContext fields

The `restricted` standard translates into these settings:

| Requirement | Field |
| --- | --- |
| No privilege escalation | `securityContext.allowPrivilegeEscalation: false` on each container |
| Drop all capabilities | `securityContext.capabilities.drop: ["ALL"]` on each container |
| Run as non-root | `runAsNonRoot: true` on the pod or each container, and no `runAsUser: 0` |
| Seccomp profile | `seccompProfile.type: RuntimeDefault` (or `Localhost`) on the pod or each container |
| Limited volume types | Use only `configMap`, `csi`, `downwardAPI`, `emptyDir`, `ephemeral`, `persistentVolumeClaim`, `projected` and `secret` |

The pod-level `securityContext` applies to every container, and a container-level setting overrides it. `runAsNonRoot: true` makes the kubelet refuse to start a container that would run as user 0. A numeric `runAsUser` makes this reliable for an image that does not declare a numeric user.

## A failing pod and a passing pod

<!-- astrona:playground:renew -->

Select the playground cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-040-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-040-03" || exit 1
```

Save this as `namespace-gate.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: gate
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
```

Apply it:

```sh
kubectl apply -f namespace-gate.yaml
```

Save this as `pod-failing-reader.yaml`. It sets a non-root user and nothing else:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: failing-reader
  namespace: gate
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f pod-failing-reader.yaml
```

The API server rejects the pod with a message that contains `violates PodSecurity "restricted:v1.35"`. The message lists the remaining problems, which are `allowPrivilegeEscalation`, `capabilities` and `seccompProfile`. The non-root setting is not listed, because it is correct.

Add the three missing settings. Save this as `pod-passing-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: passing-reader
  namespace: gate
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

Apply it and wait for the pod:

```sh
kubectl apply -f pod-passing-reader.yaml
kubectl -n gate wait --for=condition=Ready pod/passing-reader --timeout=120s
```

## Exemptions

A cluster administrator can configure PSA in the API server admission configuration. Defaults for each mode and exemptions are set there: a list of usernames, of runtime class names and of namespaces that PSA does not check. An exemption is a cluster-wide decision, not a namespace label, so a namespace owner cannot grant it to themselves. Review the exemption list when you audit a cluster, because an exempt namespace has no pod-level protection.

## PSA in a release decision

PSA is the last check before a pod exists, and it complements the static tools. Kubesec and KubeLinter find risky settings before the release and give advice. PSA enforces a minimum on the cluster even when a person skips the pipeline. Neither one scans the image, so the release decision still needs an image scan and a written exception list.

You can now read a PSA error, fix the pod and place PSA next to the other checks. The module summary closes the idea.

## Common pitfalls

> [!WARNING]
> - **Setting `runAsNonRoot: true` and nothing else.** The other three requirements remain.
> - **Reading only the first error.** The message lists all violated fields at once.
> - **Forgetting exemptions.** A pod in an exempt namespace or from an exempt user bypasses the standard.
> - **Treating PSA as a replacement for scanning.** PSA checks fields, not packages.
