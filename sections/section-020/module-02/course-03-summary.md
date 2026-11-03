---
draft: true
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Summary

A software bill of materials lists the components of one artifact in a machine-readable form. It is useful only when it describes exactly the image that runs, and when the reader knows what it leaves out.

## What you learned

SPDX and CycloneDX are the two standard formats. Both record a subject, a list of components and the relationships between them. SPDX uses `packages`, `externalRefs` and `relationships`. CycloneDX uses `metadata.component`, `components` and `dependencies`. The content matters more than the format, so tools exchange documents by comparing names, versions and package URLs.

A package URL names a component without depending on one tool. It has a type, a namespace, a name, a version and optional qualifiers. For Alpine packages the type is `apk` and the namespace is `alpine`. A package line from `apk info -v` ends with a version and a release, so the name is everything before the last two dashes. A catalog tool finds packages with catalogers, and a package that no cataloger reads is missing from the document.

A scanner matches the package URL and version of each component to advisories and reports a finding when the version is in an affected range. A VEX statement records that a finding does not apply, with a status and a justification, and it needs an owner and a review date. An SBOM bound to a tag is ambiguous. The digest in the `imageID` field of the pod status names the running content, and an attestation signed with Cosign attaches the SBOM to that digest in the registry.

- An SBOM says what is present, not what is exploitable.
- Bind every SBOM to an image digest.
- Check completeness by comparing with the package database of the running image.
- Treat VEX statements and signatures as claims with an owner.

<!-- astrona:playground:destroy -->
