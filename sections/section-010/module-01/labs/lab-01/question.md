---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Serve Content With A Minimal Runtime

Solve this question on: `terminal`

Select an image providing only the required HTTP process and verify its running contents.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-01-01" || exit 1
node_name="astro-ats-035-lab-010-01-01-control-plane"
worker_name="astro-ats-035-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. In the namespace `starfleet-035-010-01-01`, create the ConfigMap `minimal-content` with the key `index.html` and the content `minimal-version=v1` followed by a newline.
2. Create the pod `minimal-server` in the same namespace with `restartPolicy: Never` and one container named `web`. It uses `docker.io/library/busybox:1.37.0` and runs `httpd -f -p 8080 -h /site`. Mount the ConfigMap as the volume `site` at `/site`, read-only.
3. Prove the result: from the `shuttle` pod, fetch `http://<minimal-server pod IP>:8080/` and see `minimal-version=v1`, and confirm that `minimal-server` has no Python interpreter.

## Constraints

- Do not change the `probe` Deployment, the `shuttle` pod or anything in `outpost-035-010-01-01`.
- Image size alone is not a vulnerability assessment; this task only removes a runtime the server does not need.

## How the answer is checked

The grader runs three checks. The first reads the ConfigMap `minimal-content`. The second checks the pod `minimal-server`: its container, command, read-only mount and the ConfigMap volume, that it is ready, and that it has no Python interpreter. The third fetches the page from the `shuttle` pod and needs `minimal-version=v1`.

Hint: `kubectl -n starfleet-035-010-01-01 exec shuttle -- wget -q -O- http://<pod IP>:8080/` fetches the page.
