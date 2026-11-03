---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Record A Release With Inventory, Digest And Pull Access

Combine a package inventory, an image digest, an SBOM format and registry pull access into one release record.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods and a ServiceAccount named probe-runner. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-020)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-020" || exit 1
node_name="astro-ats-035-capstone-020-control-plane"
worker_name="astro-ats-035-capstone-020-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the ConfigMap release-record in starfleet with these keys. image: docker.io/library/python:3.13-alpine. runtimeImageID: the imageID of a ready probe container. imageDigest: the part of the imageID after the last at sign, or the whole value when it has no at sign. sbomFormat: CycloneDX. scope: alpine-installed-packages. packages: a JSON list of the sorted lines of apk info -v from a probe pod. Then create the Secret registry-credentials of type kubernetes.io/dockerconfigjson in starfleet for the registry registry.example.test with the user builder and the password s3cret-pull-token, add it to the imagePullSecrets of the existing ServiceAccount probe-runner, and run a pod named release-runner with that service account, the image docker.io/library/busybox:1.37.0 and the command sleep 3600. The pod must receive the pull secret through its service account. Preserve the original application. The record is evidence for one image; it is not a signature, a provenance attestation or a vulnerability scan.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
