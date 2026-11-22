---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Record The Images That Run In A Namespace

Solve this question on: `terminal`

List every container that runs in a namespace, including init containers, with the image it requested and the image ID that the container runtime resolved.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The namespace `starfleet-035-020-01-02` runs two `probe` replicas, each with an init container named `prepare`, and the `shuttle` client pod. The namespace `outpost-035-020-01-02` runs the `drifter` pod. No image inventory exists yet.

The fleet security officer needs to know exactly which content runs in `starfleet-035-020-01-02` before any other control is planned.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-01-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-01-02" || exit 1
```

Keep this connection selected. Every command in this lab works on this cluster only.

## Tasks

1. In the namespace `starfleet-035-020-01-02`, read the `status.containerStatuses` and `status.initContainerStatuses` of every pod. Each entry has the container `name`, the `image` reference and the `imageID` that the container runtime resolved.
2. Write one line for each container, app containers and init containers alike, with four fields separated by single spaces: the pod name, the container name, the `image` value and the `imageID` value. Example shape: `<pod> <container> <image> <imageID>`.
3. Create the ConfigMap `image-inventory` in `starfleet-035-020-01-02` with these lines under the key `containers`. List each container once and add no other lines.

## Constraints

- Do not change, restart or delete the `probe` Deployment, its pods or the `shuttle` pod. The grader compares your lines with the pods that run when it checks.
- Do not list pods from `outpost-035-020-01-02`.
- Copy the values from the pod status. Do not type a tag in place of an `imageID`.

## How the answer is checked

The grader runs three checks against the live pod status. The first checks that every app container has a line with its pod, container name and image. The second checks the same for every init container. The third checks that every line carries the current `imageID` of its container and that no line is missing, extra or repeated.
