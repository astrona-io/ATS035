---
exam_objectives:
- Minimize base image footprint
---
# Run A Pinned Web Server With A Resource Budget And A Service

Solve this question on: `terminal`

Run a minimal BusyBox web server as a Deployment pinned to a digest, give it CPU and memory requests and a 64Mi memory limit, and reach it from the `shuttle` pod through a Service on port 80.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Starting state

The `shuttle` pod in `starfleet-035-010-03-03` must read a small status page from a new web server. The team wants the server to run the exact BusyBox content that `shuttle` already runs, with a fixed memory budget, behind a stable name.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Tasks

1. Create the ConfigMap `minimal-site` in `starfleet-035-010-03-03` with one key, `index.html`, whose value is the line `minimal-web-version=v1`.
2. Create the Deployment `minimal-web` in `starfleet-035-010-03-03` with one replica and the pod label `app: minimal-web`. It has one container named `web`:
   - The image is `docker.io/library/busybox@sha256:<digest>`, where `<digest>` is the digest in the `imageID` of the running `shuttle` pod, with `imagePullPolicy: IfNotPresent`.
   - The command is `httpd -f -p 8080 -h /site`, and the container port 8080 has the name `http`.
   - The ConfigMap `minimal-site` is mounted read-only at `/site`.
3. Give the `web` container a CPU request, a memory request and a memory limit of `64Mi`.
4. Create the Service `minimal-web` that selects `app: minimal-web`, listens on port 80 and targets the named port `http`. From the `shuttle` pod, `wget -qO- http://minimal-web` must print `minimal-web-version=v1`.

## Constraints

- Do not change the `shuttle` pod.
- Do not change the `drifter` pod in `outpost-035-010-03-03`.

## How the answer is checked

The grader runs three checks. The first reads the Deployment: one replica, a complete rollout, the image pinned to the digest of the `shuttle` pod with `IfNotPresent`, the `httpd` command, the port name `http` on 8080, and the `minimal-site` ConfigMap mounted read-only at `/site`. The second needs a CPU request, a memory request and a `64Mi` memory limit, and reads `/sys/fs/cgroup/memory.max` in every running `minimal-web` pod, which must hold `67108864`. The third reads the Service and sends a request from `shuttle` to `http://minimal-web`. Every check also confirms that `shuttle` is unchanged and ready.
