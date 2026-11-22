---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Diagnose A Failed Image Pull And Record The Resolved Image

Solve this question on: `terminal`

Read why a pod cannot pull its image, repair the image reference, and record the reference the pod requested next to the image ID that the node resolved.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The `scout` pod in `starfleet-035-020-03-02` never started. Its Deployment `scout` has one container, `client`, and the pod waits with an image pull error. The `drifter` pod in `outpost-035-020-03-02` runs normally.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-03-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-03-02" || exit 1
```

Keep this connection selected. Every command in this lab talks to the API server of this cluster only.

## Tasks

1. Find the image reference that the `scout` pod asks for and read the events of the namespace to learn why the pull fails. Create the ConfigMap `pull-diagnosis` in `starfleet-035-020-03-02` with the key `failedImage` set to that image reference, and the key `cause` set to `unauthorized` if the registry refused the credential, or to `missing-manifest` if the tag or digest does not exist.
2. Change the container `client` of the Deployment `scout` to the image `docker.io/library/busybox:1.37.0` and wait until the rollout is complete.
3. Create the ConfigMap `pull-evidence` in the same namespace with the key `requested` set to the image in the specification of the running `scout` pod, and the key `resolved` set to the `imageID` in the status of its container `client`.

## Constraints

- Keep the Deployment at one replica and keep the container name `client`.
- Do not change the `drifter` pod in `outpost-035-020-03-02`.

## How the answer is checked

The grader runs three checks. The first reads `failedImage` and `cause` in `pull-diagnosis`. The second reads the Deployment, requires a complete rollout and needs every running `scout` container to use `docker.io/library/busybox:1.37.0`. The third compares `requested` and `resolved` in `pull-evidence` with the specification and the status of a running, ready `scout` container. In every check the `drifter` pod must still run.
