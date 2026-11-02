---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Running Minimal Images In A Cluster

A minimal image removes tools from the filesystem, but the pod specification decides what the process may do with the files that remain. A process that runs as root with a writable root filesystem can still change its own container. Minimal images also change how you debug, because there is no shell to open, and they change how you read pull errors, because the node must find an image that matches the reference exactly. This part applies a restricted pod, debugs it without a shell in the image and breaks an image reference on purpose.

## Restrict what the container can do

Two fields of the container `securityContext` pair well with a minimal image. `readOnlyRootFilesystem: true` mounts the root filesystem of the container read-only, so a process cannot write a new binary or change a configuration file. `runAsNonRoot: true` makes the kubelet refuse to start a container whose user ID is 0. The pod can still get a writable scratch directory from an `emptyDir` volume mounted at a path such as `/tmp`.

Select the playground cluster first:

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-010-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-010-01" || exit 1
```

Save this as `pod-web-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-check
  namespace: starfleet
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    runAsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: docker.io/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      volumeMounts:
        - name: scratch
          mountPath: /tmp
  volumes:
    - name: scratch
      emptyDir: {}
```

Apply it:

```sh
kubectl apply -f pod-web-check.yaml
```

Then check the result. Wait for the pod to become ready, then try to write a file in the root filesystem and in the scratch directory:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/web-check --timeout=120s
kubectl -n starfleet exec web-check -- id
kubectl -n starfleet exec web-check -- touch /blocked
kubectl -n starfleet exec web-check -- touch /tmp/allowed
```

The `id` command reports user ID 10001. The write to `/blocked` fails with a read-only filesystem error from the container runtime's filesystem mount, and the `touch /tmp/allowed` command succeeds because `/tmp` is a separate volume. The component that enforces each rule is the container runtime on the node (containerd with runc), which applies the user, the mount options, the capability set and the seccomp profile when it creates the container. The API server only stores the fields.

## Debug an image that has no shell

A distroless or `scratch` image has no `sh`, so `kubectl exec -it pod -- sh` fails. An **ephemeral container** is a temporary container that you add to a running pod. It shares the pod's network namespace and volumes, and with `--target` it also shares the process namespace of one container. It brings its own image, so the tools live in the debug image and not in the production image.

The `web-check` pod does have a shell, but the command below works the same on a pod that does not. Start an ephemeral container with BusyBox, then run `ps` inside it and leave with `exit`:

```sh
kubectl -n starfleet debug -it web-check --image=docker.io/library/busybox:1.37.0 --target=app -- sh
```

With `--target=app`, the `ps` output includes the `sleep` process of the `app` container. You can inspect its filesystem through `/proc/<pid>/root`. The ephemeral container is added to the pod specification and it cannot be removed; it runs until you leave it, and the pod keeps the record of it. Use a debug image from a registry your policy allows, and remember that the debug container starts with the default security settings of the profile. If a namespace enforces a restricted policy, the ephemeral container must satisfy it too.

## Read an image pull failure

A pod that references an image the node cannot get stays in the `Pending` phase while its container waits. Break the reference on purpose to see how it looks. Save this as `pod-bad-image.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-image
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: unapproved.example/library/busybox:1.37.0
      command: ["sh", "-c", "sleep 3600"]
```

Apply it:

```sh
kubectl apply -f pod-bad-image.yaml
```

Then check the result. Watch the status for a short time, then read the events:

```sh
kubectl -n starfleet get pod bad-image
kubectl -n starfleet describe pod bad-image
```

The STATUS column first shows `ErrImagePull` and later `ImagePullBackOff`. The first is the failed attempt by the kubelet through the container runtime. The second is the waiting period between retries, which grows after each failure. At the end of the `describe` output, the events list the reason in the message of the `Failed` event. For this reference, the host name cannot be resolved or reached. A missing tag gives a "not found" message, a private repository without credentials gives an authorization error, and an image without a variant for the node architecture gives a platform error. Read the message before you change anything.

The pull behaviour depends on `imagePullPolicy`. If you leave the field out, Kubernetes sets `Always` for the tag `latest` or no tag, and `IfNotPresent` for any other tag or a digest. With `IfNotPresent`, the node uses an image that it already holds under that exact reference. This is why a mutable tag with `IfNotPresent` can run different content on different nodes: each node keeps whatever it pulled first. A digest reference removes this risk, because only content with that digest matches. Delete the broken pod:

```sh
kubectl -n starfleet delete pod bad-image --now
```

You can now run a minimal image with a restricted pod, debug it with an ephemeral container and read the status that a bad image reference produces. The task on the next page asks you to serve content from a minimal image in the same cluster.

## Common pitfalls

> [!WARNING]
> - **Setting `readOnlyRootFilesystem: true` without a writable volume.** Programs that write to `/tmp` or a cache directory crash. Mount an `emptyDir` at the paths that need to be writable.
> - **Using `runAsNonRoot: true` with an image whose user is a name.** The kubelet reports an error that it cannot verify the user. Set `runAsUser` or use a numeric `USER`.
> - **Relying on a mutable tag with `IfNotPresent`.** Two nodes can run different content under the same tag. Use a digest.
> - **Fixing `ImagePullBackOff` before reading the event message.** The reason decides the fix: name, tag, credentials or architecture.
