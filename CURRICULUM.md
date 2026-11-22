# Curriculum Coverage

> Historical design record. Counts and execution claims below describe the original expansion. For current labs, preparation and practical limits, use [LAB-COVERAGE.md](LAB-COVERAGE.md) and [COVERAGE-REVIEW.md](COVERAGE-REVIEW.md).

Exam: Certified Kubernetes Security Specialist (CKS). Domain: Supply Chain Security (20%).

The [official objectives](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) were checked on 2026-10-11. Teaching structure is independently authored and does not add official requirements.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Minimize base image footprint | 3 |
| 020 | Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories) | 3 |
| 030 | Secure your supply chain (permitted registries, sign and validate artifacts, etc.) | 3 |
| 040 | Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter) | 3 |

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize The Base Image Footprint | Layers, Tags And Digests; Multi-Stage Builds And Minimal Base Images; Hardening A Dockerfile; Running Minimal Images In A Cluster; Build And Inspect The Final Image |
| 010 / 02 | Compare Base Images And Their Attack Surface | What Each Base Image Contains; Measure What A Running Container Can Reach |
| 010 / 03 | Keep Images Small And Fresh Over Time | Pin Images By Digest And Keep The Pin Current; Pull Policy, Rebuild Cadence And Size Budgets |
| 020 / 01 | Understand The Software Supply Chain | Stages, Trust Boundaries And Evidence; Software Bills Of Materials With Syft; Vulnerability Scanning With Trivy; CI/CD Pipelines And Artifact Repositories |
| 020 / 02 | Generate And Read Software Bills Of Materials | Reading SPDX And CycloneDX Documents; Matching An SBOM To Vulnerabilities And An Image Digest |
| 020 / 03 | Provenance, Artifact Repositories And Pull Access | Registries, Repositories And Who May Push Or Pull; Pull Secrets And Service Accounts; Prove An Image Pull Uses Registry Credentials; Build Provenance And SLSA Levels |
| 030 / 01 | Admission Control, Permitted Registries And Signed Images | The Admission Pipeline And ValidatingAdmissionPolicy; Enforcing Permitted Registries; Policy Engines And Admission Webhooks; Signing And Verifying Images With cosign; Verify Who Signed An Image Digest |
| 030 / 02 | Require Image Digests And Verify Signatures | A Digest Rule With ValidatingAdmissionPolicy; Signatures, Attestations And Keyless Signing; Enforcing Verification And Its Limits |
| 030 / 03 | ImagePullSecrets, ImagePolicyWebhook And Admission Failure Modes | Pull Credentials For Private Registries; The ImagePolicyWebhook Admission Plugin; Admission Failure Modes And Exemptions |
| 040 / 01 | Static Analysis Of Workloads And Images | What Static Analysis Can And Cannot Show; Scanning Manifests With Kubesec; Linting Manifests With KubeLinter; A Release Decision With Image Scans And Pod Security Admission |
| 040 / 02 | Scan Images And Configuration With Trivy | What Trivy Scans: Images, Folders And Configuration; Severity Filters, Unfixed Findings And Exit Codes; Exceptions, Database Freshness And What A Finding Proves; Use A Fresh Scan As Release Evidence |
| 040 / 03 | Enforce Workload Standards With Pod Security Admission | The Pod Security Standards; Namespace Labels, Modes And Versions; Meeting The Restricted Standard, Exemptions And Limits |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. Question banks are separate from the reading manifest and follow their declared summaries. Each module has a playground and at least one graded lab, each section has a knowledge check, and the second and third modules of each section have their own knowledge check.

## Hands-On Coverage

This course has 12 ungraded module playgrounds, all on kind, and 15 graded labs (12 on kind, 3 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. Every lab passed `astrona validate` and `astrona test` on its own runtime, and every playground started with `scripts/ci/test-playground.sh`.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Serve Content With A Minimal Runtime; Build A Minimal Runtime Image |
| 010/02 | Run A Pod With A Restricted Security Context |
| 010/03 | Pin An Image To The Digest The Node Reports |
| 020/01 | Bind A Package Inventory To A Running Image |
| 020/02 | Record A Structured Package Inventory |
| 020/03 | Repair Authenticated Image Pulls |
| 030/01 | Enforce An Approved Image Registry; Sign And Verify An Immutable Image |
| 030/02 | Require Image Digests In A Namespace |
| 030/03 | Enforce A Registry Policy And Attach Pull Credentials |
| 040/01 | Analyze And Correct A Workload Security Document |
| 040/02 | Decide A Scan Gate From Scan Results; Scan An Image And Bind The Release Decision |
| 040/03 | Enforce The Restricted Pod Security Standard |
