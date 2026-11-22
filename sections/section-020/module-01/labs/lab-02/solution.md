---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Record The Images That Run In A Namespace Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-01-02" || exit 1
```

Keep this connection selected. Every command in this lab works on this cluster only.

## Inspect the pods

An inventory starts from what runs now, so look at the pods first. The `-o wide` output also shows the node of each pod.

```sh
kubectl -n starfleet-035-020-01-02 get pods -o wide
```

You see two `probe` pods and the `shuttle` pod. The pod list does not show the init container `prepare`, because it finished before the `probe` container started. The kubelet still keeps its status in `status.initContainerStatuses`, and that status holds the `imageID` of the content that ran.

## Read the status of every container

The kubelet writes one status entry for each container. The `image` field is the reference that the pod asked for. The `imageID` field is the identity of the content that the container runtime (containerd) resolved for it. Read both lists for one pod, with the pod name in front of each line, in a loop over all pods:

```sh
for pod in $(kubectl -n starfleet-035-020-01-02 get pods -o jsonpath='{.items[*].metadata.name}'); do
  kubectl -n starfleet-035-020-01-02 get pod "$pod" -o jsonpath='{range .status.initContainerStatuses[*]}{.name}{" "}{.image}{" "}{.imageID}{"\n"}{end}{range .status.containerStatuses[*]}{.name}{" "}{.image}{" "}{.imageID}{"\n"}{end}' |
    sed "s|^|$pod |"
done | sort > inventory.txt
cat inventory.txt
```

The file has five lines: a `prepare` line and a `probe` line for each `probe` pod, and one `client` line for the `shuttle` pod. Both `probe` pods show the same `imageID` for the `probe` container, because they run the same content. The `shuttle` pod has no init container, so the first `range` prints nothing for it.

## Store the inventory

Create the ConfigMap from the file, with the key `containers`:

```sh
kubectl -n starfleet-035-020-01-02 create configmap image-inventory --from-file=containers=inventory.txt
```

Then check the result:

```sh
kubectl -n starfleet-035-020-01-02 get configmap image-inventory -o jsonpath='{.data.containers}'
```

The output repeats the five lines of `inventory.txt`. The values come from the pod status, so they describe the content that runs now. If a pod is replaced later, its name changes and the inventory must be read again.

After recording your result, remove the lab with `astrona destroy ats-035-lab-020-01-02`.

## Common pitfalls

> [!WARNING]
> - **Reading only `containerStatuses`.** Init containers run code too, and their status is in `initContainerStatuses`.
> - **Recording the tag from the pod specification as the identity.** A tag can move to other content. The `imageID` in the status names the content that the runtime used.
> - **Restarting or scaling the `probe` Deployment while you work.** New pods get new names, and the old lines no longer match the cluster.
