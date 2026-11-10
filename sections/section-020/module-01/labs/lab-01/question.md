---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Bind A Package Inventory To A Running Image

Solve this question on: `terminal`

Record installed operating-system packages and the image identity actually running them.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-01-01" || exit 1
node_name="astro-ats-035-lab-020-01-01-control-plane"
worker_name="astro-ats-035-lab-020-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Tasks

1. Pick a ready `probe` pod in the namespace `starfleet-035-020-01-01` and read the `imageID` of its container `probe`.
2. List the installed operating-system packages in that pod with `apk info -v`.
3. Create the ConfigMap `supply-inventory` in the same namespace with these keys: `image` set to `docker.io/library/python:3.13-alpine`, `runtimeImageID` set to the image ID from step 1, `packages` set to the sorted `apk info -v` lines as a JSON list, and `scope` set to `alpine-installed-packages`.

## Constraints

- Do not change the `probe` Deployment, its pods or the client pods.
- This is an operating-system package inventory. It is not a complete software bill of materials (SBOM), a signature proof or a vulnerability scan.

## How the answer is checked

The grader runs two checks. The first reads `image`, `scope` and `runtimeImageID`, which must match the image ID of a ready `probe` container. The second runs `apk info -v` in a `probe` pod and compares the sorted lines with the JSON list in `packages`.
