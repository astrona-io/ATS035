---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Summary

A small image stays secure only while it is exact and current. The reference names the content, the pull policy decides when a node fetches it, and a rebuild process replaces it when the base image is fixed.

## What you learned

A digest is the SHA-256 hash of an image manifest, and a reference with a digest selects the same bytes on every node. The runtime refuses content that does not match. A digest pin also freezes the vulnerabilities of that content, so a pinned reference needs an owner. Renovate and Dependabot read the tag and digest from repository files and open a pull request with the newer digest. The change then goes through review and deployment like any other change. A reference that carries both a tag and a digest uses the digest, and the tag only helps a reader.

The `imagePullPolicy` field decides when a node pulls. `IfNotPresent` pulls when the image is missing, `Always` asks the registry each time, and `Never` never pulls. Kubernetes picks `Always` for `latest` or an untagged reference and `IfNotPresent` for the others. A moving tag with `IfNotPresent` lets nodes run different content under the same name, and `Never` produces `ErrImageNeverPull` on a node that lacks the image.

An image is a copy of its base image at build time, so a fix in the base reaches a workload only after a rebuild, a new digest and a redeployment. Rebuild on a schedule and when a scanner reports a fixed vulnerability, and pull the base explicitly so a cache does not repeat old content. A size budget, a `.dockerignore` file and registry retention rules keep images small and remove old builds. An immutable-tag setting stops a tag from moving.

- Run by digest when exact content matters, and update the digest by pull request.
- Rebuild on a schedule and on a fixed vulnerability.
- Keep a size budget and remove unneeded files from the build context.
- Delete old images from the registry and make tags immutable.

<!-- astrona:playground:destroy -->
