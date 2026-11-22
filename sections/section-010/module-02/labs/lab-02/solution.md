---
exam_objectives:
- Minimize base image footprint
---
# Compare Base Images And Move A Workload To The Smaller One Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-02-02" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Read what the probe image contains

The `probe` pods run `python:3.13-alpine`, an Alpine based image. Alpine uses the `musl` C library, so its dynamic loader is a file named `ld-musl` followed by the processor architecture. The `apk` package manager knows every installed package. Read both facts in one running `probe` pod. The `kubectl exec deploy/probe` form picks one pod of the Deployment for you:

```sh
kubectl -n starfleet-035-010-02-02 exec deploy/probe -- sh -c 'ls /lib/ld-musl*'
kubectl -n starfleet-035-010-02-02 exec deploy/probe -- sh -c 'apk info | wc -l'
```

The first command prints one full path under `/lib`. The architecture part of the name depends on the node, so copy the path exactly as your cluster prints it. The second command prints one number: the count of installed `apk` packages, the Python interpreter among them.

Save this as `configmap-base-image-report.yaml`. Replace `<LOADER>` with the path and `<PACKAGES>` with the number that your cluster printed. Keep the quotes around the number, because a ConfigMap value must be a string:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: base-image-report
  namespace: starfleet-035-010-02-02
data:
  probeLoader: <LOADER>
  probePackages: "<PACKAGES>"
```

Apply it:

```sh
kubectl apply -f configmap-base-image-report.yaml
```

## Move the beacon to BusyBox

The `beacon` container only runs a shell loop with `wget`. Both are BusyBox commands, and the BusyBox image has them too. The BusyBox image has no package manager and no language runtime, so moving the workload removes the Python interpreter and `apk` from the running container while the command keeps working. Look at the current image first:

```sh
kubectl -n starfleet-035-010-02-02 get deployment beacon -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Save this as `deployment-beacon.yaml`. Only the `image` line differs from the running Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: beacon
  namespace: starfleet-035-010-02-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: beacon
  template:
    metadata:
      labels:
        app: beacon
    spec:
      containers:
      - name: beacon
        image: docker.io/library/busybox:1.37.0
        command:
        - sh
        - -c
        - while true; do wget -qO- -T 3 http://probe/ || echo probe-unreachable; sleep 5; done
```

Apply it:

```sh
kubectl apply -f deployment-beacon.yaml
```

The Deployment controller creates a new ReplicaSet with the new pod template and removes the old pod after the new one runs. Wait for the rollout to finish:

```sh
kubectl -n starfleet-035-010-02-02 rollout status deployment/beacon --timeout=180s
```

## Verify the result

Look up `apk` and `python` in the new `beacon` pod. Each lookup must fail, so the whole command prints nothing and returns a nonzero status:

```sh
kubectl -n starfleet-035-010-02-02 exec deploy/beacon -- sh -c 'which apk || which python'
```

Then read the log of the new pod. It must hold lines with `version=v1`, the text that the `probe` server sends in each response, and not the fallback text `probe-unreachable`:

```sh
kubectl -n starfleet-035-010-02-02 logs deploy/beacon --tail=3
```

The workload now runs on an image with one program instead of a language runtime and a package manager. It still has a shell, so this is a smaller image, not a shell-free one.

After recording your result, remove the lab with `astrona destroy ats-035-lab-010-02-02`.

## Common pitfalls

> [!WARNING]
> - Typing the loader path from memory. Its name contains the architecture of the node, so copy what `ls` prints in your cluster.
> - Writing the package count without quotes in the YAML. A ConfigMap value must be a string, and the API server rejects a number.
> - Changing the command together with the image. Change only the image, so that the result shows that the same command works on the smaller image.
