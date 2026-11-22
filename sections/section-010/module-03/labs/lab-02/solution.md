---
exam_objectives:
- Minimize base image footprint
---
# Choose An Image Pull Policy From What The Node Holds Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-02" || exit 1
worker_name="astro-ats-035-lab-010-03-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Find out why offline-runner does not start

The kubelet on the worker node decides whether to pull an image, based on the `imagePullPolicy` field of the container. With `Never`, the kubelet only looks in the local image store of the container runtime. Read the status and the last events of the pod:

```sh
kubectl -n starfleet-035-010-03-02 get pod offline-runner
kubectl -n starfleet-035-010-03-02 describe pod offline-runner | tail -n 8
```

The status column shows `ErrImageNeverPull`. The events say that the image is not present on the machine and that the pull policy is `Never`. No registry was contacted. Now list what the container runtime on the worker node holds. This command runs only inside the worker node container of this lab:

```sh
podman exec "$worker_name" crictl images --digests | grep -E 'IMAGE|busybox'
```

The output has a row for `docker.io/library/busybox` with the tag `1.37.0`, and no row for `1.36.1`. So the pod can start without a pull only if it names the tag that the node holds.

## Repair offline-runner

You could change the image of the running pod in place, but a new pod from a file is easier to read and repeat. Delete the old pod first:

```sh
kubectl -n starfleet-035-010-03-02 delete pod offline-runner --wait=true
```

Save this as `pod-offline-runner.yaml`. Only the `image` line differs from the old pod, and `imagePullPolicy` stays `Never`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: offline-runner
  namespace: starfleet-035-010-03-02
  labels:
    app: offline-runner
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: docker.io/library/busybox:1.37.0
    imagePullPolicy: Never
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f pod-offline-runner.yaml
```

Then check the result:

```sh
kubectl -n starfleet-035-010-03-02 wait --for=condition=Ready pod/offline-runner --timeout=120s
```

The pod becomes Ready. The kubelet found the image in the local store and started the container without a request to any registry.

## Make relay ask the registry on every start

With `IfNotPresent`, the kubelet uses the copy on the node as long as it exists, even if the tag has moved in the registry since. With `Always`, the kubelet asks the registry for the current digest each time a container starts. It downloads layers only when the digest differs from what the node holds. Read the events of the current `relay` pod first, to see the old behavior:

```sh
kubectl -n starfleet-035-010-03-02 get events --field-selector reason=Pulled
```

The `Pulled` event of the `relay` pod says that the image is already present on the machine. Save this as `deployment-relay.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: relay
  namespace: starfleet-035-010-03-02
spec:
  replicas: 1
  selector:
    matchLabels:
      app: relay
  template:
    metadata:
      labels:
        app: relay
    spec:
      containers:
      - name: relay
        image: docker.io/library/busybox:1.37.0
        imagePullPolicy: Always
        command:
        - sh
        - -c
        - sleep 3600
```

Apply it:

```sh
kubectl apply -f deployment-relay.yaml
```

The new pull policy is part of the pod template, so the Deployment controller rolls out a new pod. Then check the result:

```sh
kubectl -n starfleet-035-010-03-02 rollout status deployment/relay --timeout=180s
kubectl -n starfleet-035-010-03-02 get pods -l app=relay
kubectl -n starfleet-035-010-03-02 get events --field-selector reason=Pulled --sort-by=.lastTimestamp
```

The pod list shows the new `relay` pod, and maybe the old one while it terminates. The last `Pulled` event in the sorted list belongs to the new pod: its message says that the kubelet successfully pulled the image, where the event of the old pod said that the image was already present on the machine. The kubelet asked the registry, even though the node already held the image.

After recording your result, remove the lab with `astrona destroy ats-035-lab-010-03-02`.

## Common pitfalls

> [!WARNING]
> - Changing `offline-runner` to `IfNotPresent` or `Always`. The pod would start, but it would contact a registry, which the task forbids.
> - Expecting `Always` to download every layer again. The kubelet compares the digest and downloads only what changed, so the `Pulled` event can come within a second.
> - Reading the events of the old `relay` pod. Select the pod that the new ReplicaSet created.
