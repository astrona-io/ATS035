---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Pin An Image To The Digest The Node Reports

Solve this question on: `terminal`

Read the digest that the node reports for the BusyBox image and start a pod that refers to the image by that digest.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The `shuttle` pod runs `docker.io/library/busybox:1.37.0` by tag. The required pod does not exist.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-01" || exit 1
node_name="astro-ats-035-lab-010-03-01-control-plane"
worker_name="astro-ats-035-lab-010-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. Read the image digest the node reports for the `shuttle` pod in the namespace `starfleet-035-010-03-01`, from the `imageID` in its container status.
2. Create the pod `pinned-runner` in the same namespace with one container named `app`. Its image is `docker.io/library/busybox@sha256:` followed by that digest, with no tag. Set `imagePullPolicy: IfNotPresent`, `restartPolicy: Never` and the command `sh -c "sleep 3600"`.
3. Wait until `pinned-runner` is Ready and check that its container status reports the same digest.

## Constraints

- Leave the `shuttle` pod unchanged.
- Do not change the `probe` Deployment or anything in `outpost-035-010-03-01`.

## How the answer is checked

The grader runs two checks. The first reads the digest from the `shuttle` pod and compares it with the image of `pinned-runner`, which must carry the digest and no tag. The second needs `pinned-runner` to be ready with that digest in its container status.

Hint: `kubectl -n starfleet-035-010-03-01 get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}'` prints the image ID.
