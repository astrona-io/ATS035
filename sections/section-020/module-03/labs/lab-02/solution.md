---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Diagnose A Failed Image Pull And Record The Resolved Image Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-03-02" || exit 1
```

Keep this connection selected. Every command in this lab talks to the API server of this cluster only.

## Read the failed pull

The pod specification holds the image reference that someone wrote. The kubelet on the node reads that reference and asks the container runtime to pull it. When the pull fails, the kubelet sets the waiting reason of the container to `ErrImagePull`, later to `ImagePullBackOff`, and records an event with the error from the registry. Start with the reference and the waiting reason:

```sh
kubectl -n starfleet-035-020-03-02 get pods -l app=scout -o custom-columns='NAME:.metadata.name,REQUESTED:.spec.containers[0].image,WAITING:.status.containerStatuses[0].state.waiting.reason'
```

The `REQUESTED` column shows `docker.io/library/busybox:1.37.0-scout`, and the `WAITING` column shows one of the two pull reasons. The reason alone does not say why the pull failed, so read the events next:

```sh
kubectl -n starfleet-035-020-03-02 get events --sort-by=.lastTimestamp
```

The `Failed` events come from the kubelet. Their message says that the reference was not found. The registry answered and had no manifest for this tag, so the cause is a missing manifest and not a refused credential. A refused credential would show `unauthorized` or `authentication required` in the message instead.

Save this as `configmap-pull-diagnosis.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pull-diagnosis
  namespace: starfleet-035-020-03-02
data:
  failedImage: docker.io/library/busybox:1.37.0-scout
  cause: missing-manifest
```

Apply it:

```sh
kubectl apply -f configmap-pull-diagnosis.yaml
```

## Repair the image reference

The Deployment controller owns the pod template, so the fix goes into the Deployment and not into the pod. The Deployment controller then creates a new ReplicaSet, and the ReplicaSet controller creates a new pod with the fixed reference. Change the image of the container `client`:

```sh
kubectl -n starfleet-035-020-03-02 set image deployment/scout client=docker.io/library/busybox:1.37.0
kubectl -n starfleet-035-020-03-02 rollout status deployment/scout --timeout=180s
```

The second command waits until the new pod is ready and reports that the rollout finished. The pod that could not pull belonged to the old ReplicaSet, so the Deployment controller removes it.

## Record what was requested and what was resolved

The specification still holds only the text that was written. The status holds the `imageID`, which the kubelet reads from the container runtime after the pull. It contains the `sha256:` digest of the content that actually runs. Read both values from the running pod:

```sh
kubectl -n starfleet-035-020-03-02 get pods -l app=scout --field-selector=status.phase=Running -o custom-columns='NAME:.metadata.name,REQUESTED:.spec.containers[0].image,RESOLVED:.status.containerStatuses[0].imageID'
```

Copy the value of the `RESOLVED` column. Save this as `configmap-pull-evidence.yaml`, and replace `<IMAGE_ID>` with that value:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pull-evidence
  namespace: starfleet-035-020-03-02
data:
  requested: docker.io/library/busybox:1.37.0
  resolved: <IMAGE_ID>
```

Apply it:

```sh
kubectl apply -f configmap-pull-evidence.yaml
```

Then check the result:

```sh
kubectl -n starfleet-035-020-03-02 get configmap pull-evidence -o jsonpath='{.data}{"\n"}'
```

The two values now sit side by side. The tag in `requested` can move to other content later. The digest in `resolved` names the exact bytes that this pod runs.

After recording your result, remove the lab with `astrona destroy ats-035-lab-020-03-02`.

## Common pitfalls

> [!WARNING]
> - Editing the failing pod instead of the Deployment. The ReplicaSet controller creates the pod again from the old template.
> - Treating every pull failure as a credential problem. Read the event message: a missing manifest and a refused credential need different fixes.
> - Copying `status.containerStatuses[0].image` instead of `imageID`. The `image` field repeats a name; only `imageID` contains the digest of the content that runs.
> - Reading the `imageID` from a pod that is not running yet. A waiting container has no `imageID`.
