---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Guided Practice: Run A Pod With A Restricted Security Context

Use a host shell with the private kubeconfig for this module playground. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-010-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-010-02" || exit 1
node_name="astro-ats-035-playground-010-02-control-plane"
worker_name="astro-ats-035-playground-010-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The `busybox:1.37.0` image already runs a shell, so the pod does not need a different image. The work is to remove what the process does not need: root, writes to the image filesystem, Linux capabilities and unfiltered system calls. Inspect the namespace before you change it:

```sh
kubectl -n starfleet get pods -o wide
```

Save this as `pod-restricted-runner.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-runner
  namespace: starfleet
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

Apply it:

```sh
kubectl apply -f pod-restricted-runner.yaml
```

## Verify The Result

Wait for the pod to become ready. Then read the user ID that the process runs as, and try to write a file in the root filesystem. The write must fail with a read-only filesystem error, so run it as its own command and expect a nonzero exit status.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/restricted-runner --timeout=180s
kubectl -n starfleet exec restricted-runner -- id -u
kubectl -n starfleet exec restricted-runner -- sh -c 'touch /should-fail'
```

The first command prints the user ID 10001. The second command prints an error from `touch` and returns a nonzero status. The `runAsUser` field is numeric on purpose: with `runAsNonRoot: true`, the kubelet refuses to start a container whose image names a user by text, because it cannot prove that the name is not root.

## Common pitfalls

> [!WARNING]
> - Setting `readOnlyRootFilesystem: true` on a program that writes to its own directories. Give such a program a writable `emptyDir` volume.
> - Putting `capabilities` or `readOnlyRootFilesystem` at pod level. Those fields exist only at container level.
> - Confirm the private context before a change. Do not change unrelated components.
