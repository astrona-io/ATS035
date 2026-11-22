---
exam_objectives:
- Minimize base image footprint
---
# Compare Base Images And Move A Workload To The Smaller One

Solve this question on: `terminal`

Read what the Alpine based probe image contains, then move a shell-only workload from that image to the smaller BusyBox image and show that it still works.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy `probe` replicas on `docker.io/library/python:3.13-alpine`, an internal Service `probe`, the `shuttle` pod on `docker.io/library/busybox:1.37.0` and the `beacon` Deployment. The `beacon` container runs a shell loop that sends a request to the `probe` Service every five seconds and prints the response. It runs on the Python image, although it uses only the shell and `wget`. The ConfigMap `base-image-report` does not exist.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-02-02" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Tasks

1. In a running `probe` pod in the namespace `starfleet-035-010-02-02`, list the `musl` dynamic loader in `/lib` and count the installed `apk` packages with `apk info | wc -l`.
2. Create the ConfigMap `base-image-report` in the same namespace with two keys: `probeLoader` holds the full loader path that `ls` printed, and `probePackages` holds the package count.
3. Change the image of the `beacon` Deployment to `docker.io/library/busybox:1.37.0`. Keep the container name `beacon` and its command unchanged.
4. Show that the new `beacon` pod has neither `apk` nor `python`, and that its log still shows the response from the `probe` Service.

## Constraints

- Do not change the `probe` Deployment, the `probe` Service or the `shuttle` pod.
- The `drifter` pod in the namespace `outpost-035-010-02-02` must stay untouched.

## How the answer is checked

The grader runs four checks. The first two read the same facts from a running `probe` pod and compare them with the keys of `base-image-report`. The third reads the `beacon` Deployment and needs a finished rollout on the BusyBox image with the original command, then runs `which apk || which python` in each ready `beacon` pod: both lookups must fail. The fourth reads the log of each ready `beacon` pod on BusyBox and needs the response text of the `probe` Service in it.
