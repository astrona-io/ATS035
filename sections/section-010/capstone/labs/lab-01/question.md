---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Run A Hardened Minimal Web Server

Serve a page from a digest-pinned BusyBox image with a restricted security context, resource limits and a Service that a client pod can reach.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The `shuttle` pod in `starfleet` runs `docker.io/library/busybox:1.37.0` by tag. The required workload does not exist.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-010)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-010" || exit 1
node_name="astro-ats-035-capstone-010-control-plane"
worker_name="astro-ats-035-capstone-010-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

In the `starfleet` namespace, create a ConfigMap named `minimal-site` whose key `index.html` holds the line `capstone-version=v1`. Create a Deployment named `minimal-web` with one replica and the label `app: minimal-web` on its pods. Its container is named `web` and runs `httpd -f -p 8080 -h /site` from the BusyBox image. Refer to the image as `docker.io/library/busybox@sha256:` followed by the digest that the node reports for the `shuttle` pod, with no tag, and set `imagePullPolicy: IfNotPresent`. Mount the ConfigMap read-only at `/site`. The container port is named `http` and is 8080.

Apply these restrictions. At pod level: `runAsNonRoot: true`, `runAsUser: 10001` and the `RuntimeDefault` seccomp profile. At container level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and all capabilities dropped. Give the container a memory limit of `64Mi` and a CPU and memory request. Create a Service named `minimal-web` on port 80 that sends traffic to the named port `http`. The `shuttle` pod must receive the page through the Service name.

## Verify The Result

The grader checks the object fields, the digest, the user ID inside the container and a request from the `shuttle` pod. Wait for the rollout to finish before submitting. Preserve the task's namespace, workload names and unrelated components.
