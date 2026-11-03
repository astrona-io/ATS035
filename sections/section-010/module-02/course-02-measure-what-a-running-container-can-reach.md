---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Measure What A Running Container Can Reach

An image only describes files. At run time, a process also has a user ID, a filesystem it may write to, a set of Linux capabilities and a list of system calls it may use. A minimal image with a root process that can write anywhere still gives an attacker a lot. This part reads those settings from inside a container and then restricts them in the pod specification.

## What a process has by default

A container process starts with the user that the image sets. Many images set no user, so the process runs as root, user ID 0. The container is isolated from the node by namespaces and cgroups, but root inside the container has more rights than a normal user, for example to write to files owned by root.

Three more things come from the container runtime and not from the image:

- A **Linux capability** is one part of the traditional root power, such as binding a port below 1024 (`NET_BIND_SERVICE`) or changing file owners (`CHOWN`). The runtime gives a container root process a default set of capabilities.
- The **root filesystem** of the container is writable by default. A writable root filesystem lets an attacker drop a tool or change a program.
- A **seccomp profile** (secure computing mode) filters system calls. The `RuntimeDefault` profile uses the filter that the container runtime ships and blocks a set of rarely needed calls. In Kubernetes, a pod without a seccomp setting runs unconfined.

## Read the defaults in the cluster

The `shuttle` pod sets none of these fields, so it shows the defaults.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-010-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-010-02" || exit 1
```

Read the user ID, the capability sets of the main process and the seccomp mode:

```sh
kubectl -n starfleet exec shuttle -- sh -c 'id -u; grep -E "^(CapEff|CapBnd|Seccomp):" /proc/1/status'
```

The user ID is 0, so the process runs as root. `CapEff` is the set of capabilities that the process uses now, written as a hexadecimal mask. A non-zero value means the process holds capabilities. `Seccomp: 0` means that no seccomp filter applies.

Now test whether the root filesystem accepts a write:

```sh
kubectl -n starfleet exec shuttle -- sh -c 'touch /written-by-the-process && ls -l /written-by-the-process'
```

The command succeeds, so an attacker with code execution can add a file anywhere that root may write.

## Restrict the pod

Five settings in the pod specification remove these defaults. Some go in `spec.securityContext` for the whole pod, and some go in the `securityContext` of each container:

- `runAsNonRoot: true` makes the kubelet refuse to start a container that would run as user ID 0. Pair it with a numeric `runAsUser`, because the kubelet cannot verify a user name.
- `seccompProfile: {type: RuntimeDefault}` applies the runtime filter. It is set on the pod or on a container.
- `allowPrivilegeEscalation: false` stops a process from gaining more rights than its parent, for example through a set-user-ID program.
- `readOnlyRootFilesystem: true` mounts the container's root filesystem read-only.
- `capabilities.drop: [ALL]` removes every capability.

Save this as `pod-restricted-check.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-check
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
kubectl apply -f pod-restricted-check.yaml
```

Then check the result. Wait for the pod, then repeat the three reads from before:

```sh
kubectl -n starfleet wait --for=condition=Ready pod/restricted-check --timeout=120s
kubectl -n starfleet exec restricted-check -- sh -c 'id -u; grep -E "^(CapEff|Seccomp):" /proc/1/status'
kubectl -n starfleet exec restricted-check -- sh -c 'touch /written-by-the-process'
```

The user ID is 10001, `CapEff` is all zeros and `Seccomp` is 2, which means that a filter applies. The `touch` command fails with an error about a read-only file system and returns a nonzero status. The image is the same BusyBox image as before. Only the pod specification changed.

## What this adds to a small image

A small image reduces the files an attacker finds. These settings reduce what the process is allowed to do with them. A program that needs to write, for example to a cache directory, gets a writable `emptyDir` volume mounted at that one path, and the root filesystem stays read-only. You can now restrict a pod to the minimum, and the next task asks you to do the same for a new pod from a task description.

## Common pitfalls

> [!WARNING]
> - **Using `runAsNonRoot` with an image user given by name.** The kubelet cannot tell if a name is root and refuses to start the container. Set a numeric `runAsUser`.
> - **Putting container fields at pod level.** `capabilities`, `readOnlyRootFilesystem` and `allowPrivilegeEscalation` exist only in a container `securityContext`.
> - **Assuming that dropping capabilities makes a root process safe.** A root process can still read and write files that root owns. Use a non-root user as well.
