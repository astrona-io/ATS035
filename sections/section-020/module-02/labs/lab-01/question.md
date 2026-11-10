---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Record A Structured Package Inventory

Solve this question on: `terminal`

Record a CycloneDX-style component list for the running probe image, bound to its image identity.

Allow about 10 minutes for the tasks. Cluster startup adds time.

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

## Tasks

1. Run `apk info -v` in a ready `probe` pod in the namespace `starfleet-035-020-02-01` and read the `imageID` of its container `probe`.
2. Build a CycloneDX document: `bomFormat` `CycloneDX`, `specVersion` `1.5` and a `components` list with one entry per package line. Each entry has `type` `library`, `name`, `version` and `purl`. Split a line such as `musl-1.2.5-r10` at its last two dashes: the name is the part before them and the version is the last two parts joined by a dash. The purl is `pkg:apk/alpine/` followed by the name, `@` and the version.
3. Create the ConfigMap `sbom-record` in the same namespace with the keys `format` (`CycloneDX`), `specVersion` (`1.5`), `subject` (the image ID), `scope` (`alpine-installed-packages`), `componentCount` (the number of packages, as a string) and `bom` (the JSON document).

## Constraints

- Do not change the `probe` Deployment, its pods or the client pods.
- This is an operating-system package list in one SBOM format. It does not include language packages, a signature or a vulnerability scan.

## How the answer is checked

The grader runs two checks. The first reads `format`, `specVersion`, `scope` and `subject`, which must match the image ID of a ready `probe` container. The second parses `bom`, compares its components with the packages installed in a `probe` pod, and checks `componentCount`.
