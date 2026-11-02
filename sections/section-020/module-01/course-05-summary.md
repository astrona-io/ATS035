---
draft: true
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Summary

The software supply chain is every step between source code and a running container: source, dependencies, base image, the CI/CD pipeline, the registry and the node. An attacker who changes any step changes what runs, and a team that cannot list the contents of its images cannot answer which workloads a new vulnerability affects.

## What you learned

Four kinds of evidence describe an artifact, and each answers one question. An SBOM lists the components. A vulnerability report matches the components with known vulnerabilities on one day. A signature binds a digest to a signer. A provenance attestation states how and where the artifact was built. All four must refer to the same digest, because a tag can move. The `imageID` field in the pod status is the place to read the digest that a node resolved, and a complete inventory also reads the init and ephemeral container statuses.

SPDX and CycloneDX are the two standard SBOM formats. SPDX comes from the Linux Foundation and started with license compliance. CycloneDX comes from OWASP and was built for security use. Syft creates either one from an image, and it lists only what it can identify. An SBOM is useful for a running workload only when it is tied to the digest that runs, which you can test by comparing the package list from the SBOM with the package list that the container reports.

Trivy matches the components of an image or an SBOM with a vulnerability database. A finding has a CVE, an installed version, a fixed version when one exists, a severity and a status. Filters such as `--severity` and `--ignore-unfixed` produce a gate, and `--exit-code 1` lets a pipeline fail on it. A scan describes one moment, so stored images and SBOMs need a scheduled rescan.

A pipeline needs short-lived credentials, least privilege, isolated runners, pinned inputs, reviewed definitions and secrets kept out of logs and layers. The best practice is to build once and promote the same digest. A registry needs private repositories, a read-only credential for nodes, immutable tags and separate repositories for candidate and release images. A cluster authenticates to a private registry with a `kubernetes.io/dockerconfigjson` Secret that a pod or ServiceAccount lists in `imagePullSecrets`. Base64 is not encryption, so RBAC decides who can read it.

- Record digests, not tags.
- An SBOM lists components; a scan reports known problems at one time.
- SPDX and CycloneDX are the standard SBOM formats.
- Build once, promote by digest, and keep credentials short-lived.

<!-- astrona:playground:destroy -->
