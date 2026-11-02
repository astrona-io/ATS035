---
draft: true
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Software Bills Of Materials With Syft

When a new vulnerability in a library becomes public, the first question is which of your images contain that library. Without a list of components, the answer needs a manual search in every image. A software bill of materials (SBOM) is that list in a machine-readable form, created once when the image is built and stored with the artifact. This part creates an SBOM for the image that the `probe` pods run and checks it against what the running pod reports.

## What an SBOM contains

An SBOM lists the components of an artifact. Each entry has a name, a version and, where possible, a package URL (purl), which is a standard string such as `pkg:apk/alpine/musl@1.2.5-r10` that names the package type, namespace, name and version. Good SBOMs also record licenses, file hashes and the relationships between components.

Two formats are common, and the exam expects you to know both:

- **SPDX** (Software Package Data Exchange) is a standard of the Linux Foundation, also published as ISO/IEC 5962. It started with license compliance and describes packages, files and relationships. It can be written as JSON, tag-value text, YAML or RDF.
- **CycloneDX** is a standard of the OWASP (Open Worldwide Application Security Project) foundation. It was designed for security use and lists `components`, their dependencies and, optionally, vulnerabilities. It is written as JSON or XML.

Syft is a command-line tool that creates SBOMs. It reads a container image, a directory, an archive or a file system, identifies the packages from package manager databases (such as the `apk` database) and from language ecosystem files, and writes the result in the format you choose. Syft only lists what it can identify. A binary that someone copied into the image without a package manager entry is not listed unless Syft finds a known marker in it.

## Create an SBOM in three formats

Run Syft on the image that the `probe` pods use. The `-o` option can repeat, and each use has the form `format=file`. Install Syft on your machine first.

<!-- astrona:playground:renew -->

```sh
syft scan docker.io/library/python:3.13-alpine \
  -o spdx-json=python.spdx.json \
  -o cyclonedx-json=python.cdx.json \
  -o syft-json=python.syft.json
```

Syft pulls or reads the image, catalogs it and writes three files. Without `-o`, it prints a table of names, versions and types to the terminal. The three files describe the same set of packages in three schemas, and the Syft native format has the most detail. Image references that Syft cannot find in a local container engine are pulled from the registry.

Read the files with `jq`. In an SPDX document the components are in the `packages` array, and in a CycloneDX document they are in `components`:

```sh
jq '.packages | length' python.spdx.json
jq '.components | length' python.cdx.json
jq -r '.components[] | "\(.name) \(.version)"' python.cdx.json | head -n 10
```

The first two commands print a count of entries. The counts can differ by a small number, because SPDX also adds a package entry for the image itself. The third command prints the first ten component names and versions. Both formats include operating system packages from Alpine and Python packages from the interpreter installation.

An SBOM should also identify what it describes. Open `python.spdx.json` and read the top-level `name` field, which holds the image reference. The reference you scanned was a tag. For a record you can trust later, scan the image by digest, so the SBOM and the artifact are tied together. The next step does this for the image that runs in the cluster.

## Compare the SBOM with the running pod

The `probe` pods run the same image. The Alpine package manager inside the container knows which packages it installed. Select the playground cluster, then collect the list from the pod:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-020-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-020-01" || exit 1
kubectl -n starfleet exec deploy/probe -- apk info -v | sort > apk-from-pod.txt
```

`apk info -v` prints each installed package with its version, such as `musl-1.2.5-r10`. Build the same kind of list from the Syft document. The Syft native format has an `artifacts` array in which each entry has a `type`, and Alpine packages have the type `apk`:

```sh
jq -r '.artifacts[] | select(.type == "apk") | "\(.name)-\(.version)"' python.syft.json | sort > apk-from-sbom.txt
diff apk-from-pod.txt apk-from-sbom.txt && echo same
```

If the two lists describe the same image, `diff` prints nothing and the shell prints `same`. If it prints differences, the usual cause is that the SBOM was made from a different image digest than the one the pod runs, for example because the tag moved between the two events, or because Syft scanned another platform than the node runs. Check the digest in the pod status and scan again with a digest reference:

```sh
kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}{"\n"}'
```

This is the core check of this part: an SBOM is only useful for a running workload when it is tied to the digest that runs. The same idea appears in the task on the next page, where the package list and the running image identity are recorded together.

## Where SBOMs are created and stored

You can create an SBOM at three points. At build time, the pipeline runs Syft (or the build tool's SBOM option) on the finished image and stores the document next to it. At release time, the document is attached to the image in the registry as an attestation. At audit time, you generate one from the image in the registry. Build-time SBOMs are the most accurate because the build knows the inputs. Documents generated later depend on what the scanner can detect.

You can now create SBOMs in the two standard formats and tie one to a running image. An SBOM lists components but does not say which of them are vulnerable. The next part matches the list against vulnerability data.

## Common pitfalls

> [!WARNING]
> - **Scanning a tag and treating the result as the running image.** Tie the SBOM to the digest from `imageID`.
> - **Assuming the SBOM is complete.** Syft lists what it identifies. Files copied in without a package record can be missing.
> - **Comparing counts across formats.** SPDX and CycloneDX count differently, such as the root package entry. Compare names and versions.
> - **Keeping the SBOM away from the artifact.** A document in a shared folder with no link to a digest cannot answer an incident question later.
