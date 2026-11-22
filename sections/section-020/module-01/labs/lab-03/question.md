---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Make An SBOM Of A Running Image With Syft

Solve this question on: `terminal`

Make a CycloneDX software bill of materials (SBOM) with Syft inside the cluster, from the exact image digest that the probe pods run, and store it with that digest.

Allow about 15 minutes for the tasks. Cluster startup adds time.

## Starting state

The `probe` Deployment in `starfleet-035-020-01-03` runs two replicas of `docker.io/library/python:3.13-alpine`. The team needs an SBOM for the image that actually runs, not for whatever the tag points to later. An SBOM is a document that lists the software components inside an artifact, with their names and versions. CycloneDX is one standard JSON format for an SBOM.

Syft is a tool that reads a container image or a folder and writes an SBOM. Its image `docker.io/anchore/syft:v1.57.0` is already on the node. The Syft image has no shell and no copy of the application files, so it must read the files of the probe image from a shared volume.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-01-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Tasks

1. Read the `imageID` of the container `probe` in a ready `probe` pod. It has the form `docker.io/library/python@sha256:<digest>`.
2. Create the Job `sbom-probe` in `starfleet-035-020-01-03`. An init container uses the image reference from step 1 and copies `/bin`, `/etc`, `/lib`, `/sbin`, `/usr` and `/var` into an `emptyDir` volume. The main container runs `docker.io/anchore/syft:v1.57.0` with the arguments `scan dir:<folder> --quiet --output cyclonedx-json` on that volume and sets the environment variable `SYFT_CHECK_FOR_APP_UPDATE` to `false`.
3. When the Job completes, save the log of its `syft` container as a file. That log is the CycloneDX document.
4. Create the ConfigMap `probe-sbom` in the same namespace with two keys: `sbom.cdx.json` holding the document from step 3, and `runtimeImageID` holding the image ID from step 1.

## Constraints

- Do not change the `probe` Deployment or its pods.
- Use Syft 1.57.0 from the pinned image. Do not write the SBOM by hand or edit the document that Syft printed.
- Do not change the `drifter` pod in `outpost-035-020-01-03`.

## How the answer is checked

The grader runs three checks. The first needs the Job `sbom-probe` to be complete, to run the Syft image, and to have an init container that ran the same image ID as a ready `probe` container. The second reads `sbom.cdx.json`: it must be a CycloneDX document from Syft 1.57.0, and its Alpine packages (the components whose package URL starts with `pkg:apk/`) must be exactly the name and version pairs in `/lib/apk/db/installed` of a running `probe` pod. The third needs `runtimeImageID` to equal the image ID of a ready `probe` container. Every check also confirms that the `probe` Deployment is unchanged and fully rolled out.
