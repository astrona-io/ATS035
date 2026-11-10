---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Pin An Image To The Digest The Node Reports Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-01" || exit 1
node_name="astro-ats-035-lab-010-03-01-control-plane"
worker_name="astro-ats-035-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

A tag can move, so the pod needs the digest of the content that already runs. The container runtime reports it in the `imageID` field of the pod status. Read that field for the `shuttle` pod:

```sh
kubectl -n starfleet-035-010-03-01 get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}'
```

The value has the form `docker.io/library/busybox@sha256:` followed by 64 hexadecimal characters. Copy only the 64 characters after `sha256:`. Print the digest on its own to make the copy easy:

```sh
kubectl -n starfleet-035-010-03-01 get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}' | sed 's/.*@sha256://'
```

Save this as `pod-pinned-runner.yaml` and replace `<DIGEST>` with the 64 characters from the previous command:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pinned-runner
  namespace: starfleet-035-010-03-01
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: docker.io/library/busybox@sha256:<DIGEST>
    imagePullPolicy: IfNotPresent
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f pod-pinned-runner.yaml
```

## Verify The Result

Wait for the pod to become ready and compare the digest that the runtime reports for both pods. The two `imageID` values must end in the same digest.

```sh
kubectl -n starfleet-035-010-03-01 wait --for=condition=Ready pod/pinned-runner --timeout=180s
kubectl -n starfleet-035-010-03-01 get pod shuttle pinned-runner -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].imageID}{"\n"}{end}'
```

After recording your result, remove the independent lab with `astrona destroy ats-035-lab-010-03-01`.

## Common pitfalls

> [!WARNING]
> - Copying the digest from the wrong place. Use the `imageID` of a running container, not an image ID of the form `sha256:` alone, which names the image configuration on one node.
> - Leaving the tag in the reference. A reference with a digest ignores the tag, but a reader still trusts the tag, so write the digest alone.
> - Confirm the private context before a change. Do not change unrelated components.
