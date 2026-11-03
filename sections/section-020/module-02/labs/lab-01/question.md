---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Record A Structured Package Inventory

Record a CycloneDX-style component list for the running probe image, bound to its image identity.

## Starting state

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-02-01" || exit 1
node_name="astro-ats-035-lab-020-02-01-control-plane"
worker_name="astro-ats-035-lab-020-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Required result

Create the ConfigMap sbom-record in starfleet with these keys. format: CycloneDX. specVersion: 1.5. subject: the imageID of a ready probe container. scope: alpine-installed-packages. componentCount: the number of installed packages as a string. bom: a JSON document with bomFormat CycloneDX, specVersion 1.5 and a components list with one entry per line of apk info -v from a probe pod. Each entry has type library, name, version and purl. Split a line such as musl-1.2.5-r10 at its last two dashes: the name is the part before them and the version is the last two parts joined by a dash. The purl is pkg:apk/alpine/ followed by the name, an at sign and the version. Preserve the original application. This is an operating-system package list in one SBOM format; it does not include language packages, a signature or a vulnerability scan.

## Verify The Result

The grader checks the required object fields and actual observations. Wait for controller convergence before submitting. Preserve the task's namespace, workload names and unrelated components.
