---
exam_objectives:
- Minimize base image footprint
---
# Choose An Image Pull Policy From What The Node Holds

Solve this question on: `terminal`

Repair a pod that may not pull by pointing it at an image the node already holds, and make a Deployment ask the registry each time its container starts.

Allow about 7 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The pod `offline-runner` has `imagePullPolicy: Never` and names `docker.io/library/busybox:1.36.1`, which the node does not hold, so it does not start. The `relay` Deployment runs `docker.io/library/busybox:1.37.0` with `imagePullPolicy: IfNotPresent`.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-02" || exit 1
worker_name="astro-ats-035-lab-010-03-02-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. Read why `offline-runner` in the namespace `starfleet-035-010-03-02` does not start, and list the BusyBox images that the worker node holds with `crictl images --digests` inside the worker node container.
2. Make `offline-runner` run without any pull: keep `imagePullPolicy: Never`, the container name `app` and the command, and change the image to `docker.io/library/busybox:1.37.0`, which the node holds. The pod must become Ready.
3. Set `imagePullPolicy: Always` on the container `relay` of the `relay` Deployment, so that the kubelet asks the registry each time the container starts. Keep the image `docker.io/library/busybox:1.37.0`.
4. Wait for the rollout and read the events of the new `relay` pod to confirm that the kubelet pulled the image.

## Constraints

- Do not change `imagePullPolicy` of `offline-runner`. The workload must start without contacting a registry.
- Do not change the `probe` Deployment, the `shuttle` pod or anything in `outpost-035-010-03-02`.

## How the answer is checked

The grader runs two checks. The first reads `offline-runner`: the container `app` must name `docker.io/library/busybox:1.37.0` with `imagePullPolicy: Never`, and the pod must be running and ready. The second reads the `relay` Deployment, which must use `imagePullPolicy: Always` with a finished rollout, and then reads the `Pulled` events of each ready `relay` pod: one must say that the kubelet successfully pulled the image.
