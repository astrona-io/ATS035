---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Give A Service Account Registry Pull Access

Solve this question on: `terminal`

Create a registry pull secret, attach it to a service account and run a pod that receives it.

Allow about 6 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods and a ServiceAccount named probe-runner. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-03-01" || exit 1
node_name="astro-ats-035-lab-020-03-01-control-plane"
worker_name="astro-ats-035-lab-020-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. In the namespace `starfleet-035-020-03-01`, create the Secret `registry-credentials` of type `kubernetes.io/dockerconfigjson` for the registry `registry.example.test` with the user `builder` and the password `s3cret-pull-token`.
2. Add the Secret to the `imagePullSecrets` of the existing ServiceAccount `probe-runner`.
3. Run the pod `release-check` with the ServiceAccount `probe-runner`, `restartPolicy: Never` and one container named `client` that uses `docker.io/library/busybox:1.37.0` and runs `sleep 3600`. The pod must receive the pull secret through its ServiceAccount, not through a pod-level setting.

## Constraints

- Do not change the `probe` Deployment or the client pods.
- The registry host and the credential are examples. The task shows how pull access is configured and does not pull from that host.

## How the answer is checked

The grader runs three checks. The first decodes the Secret and needs the user, the password and a matching `auth` field for `registry.example.test`. The second reads the `imagePullSecrets` of the ServiceAccount `probe-runner`. The third reads the pod `release-check`: its ServiceAccount, its container and the pull secret Kubernetes added from the ServiceAccount.
