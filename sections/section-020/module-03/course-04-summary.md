---
draft: true
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Summary

An image is trusted because of where it is stored, which credential is allowed to pull it and how it was built. Each of the three can fail alone, so each needs its own control.

## What you learned

A registry stores repositories, and a repository stores images identified by digest, with tags as movable names. A registry should keep tags immutable, separate the right to push from the right to pull, apply retention rules that never remove deployed images, write audit logs and, where possible, scan or verify images on push. A pipeline identity pushes, a cluster identity pulls, and developers have neither right by default.

The kubelet pulls with a credential from a secret of type `kubernetes.io/dockerconfigjson`. The key `.dockerconfigjson` holds an `auths` object keyed by registry host, with a user, a password and the Base64 `auth` field. A pod names such secrets in `spec.imagePullSecrets`. A service account can name them in its own `imagePullSecrets`, and an admission step copies them into every pod created with that account. The secret and the pod must be in the same namespace, and existing pods keep their old list.

Provenance records how an artifact was built: the subject digest, the builder, the source revision and the run details. A signed provenance attestation lets a consumer check those fields against policy. SLSA Build L1 asks for provenance, L2 for provenance signed by a hosted build platform, and L3 for a hardened, isolated platform that a build cannot use to forge its own record. Provenance proves origin and process, not that the inputs were safe.

- Few identities push; each workload pulls with the narrowest credential.
- Name the pull secret on the service account, in the same namespace.
- Use digests and keep the signed provenance tied to them.
- Read provenance together with the SBOM and a scan.



## Independent live assessment

Prepare with [Prove An Image Pull Uses Registry Credentials](course-02a-prove-an-authenticated-pull.md). [Repair Authenticated Image Pulls](labs/lab-01/question.md) uses its own kind environment. The pull Secret authenticates to the live private registry; ServiceAccount probe-runner lists registry-credentials in imagePullSecrets; A fresh Pod pulls and runs the private image using the ServiceAccount credential.

<!-- astrona:playground:destroy -->
