# Supply Chain Security (ATS035)

Certified Kubernetes Security Specialist (CKS): Supply Chain Security, worth 20% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Technical content remains draft. Private playgrounds and draft graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize The Base Image Footprint | Layers, Tags And Digests; Multi-Stage Builds And Minimal Base Images; Hardening A Dockerfile; Running Minimal Images In A Cluster |
| 010 / 02 | Compare Base Images And Their Attack Surface | What Each Base Image Contains; Measure What A Running Container Can Reach |
| 010 / 03 | Keep Images Small And Fresh Over Time | Pin Images By Digest And Keep The Pin Current; Pull Policy, Rebuild Cadence And Size Budgets |
| 010 / capstone | Run A Hardened Minimal Web Server | Capstone lab |
| 020 / 01 | Understand The Software Supply Chain | Stages, Trust Boundaries And Evidence; Software Bills Of Materials With Syft; Vulnerability Scanning With Trivy; CI/CD Pipelines And Artifact Repositories |
| 020 / 02 | Generate And Read Software Bills Of Materials | Reading SPDX And CycloneDX Documents; Matching An SBOM To Vulnerabilities And An Image Digest |
| 020 / 03 | Provenance, Artifact Repositories And Pull Access | Registries, Repositories And Who May Push Or Pull; Pull Secrets And Service Accounts; Build Provenance And SLSA Levels |
| 030 / 01 | Admission Control, Permitted Registries And Signed Images | The Admission Pipeline And ValidatingAdmissionPolicy; Enforcing Permitted Registries; Policy Engines And Admission Webhooks; Signing And Verifying Images With cosign |
| 030 / 02 | Require Image Digests And Verify Signatures | A Digest Rule With ValidatingAdmissionPolicy; Signatures, Attestations And Keyless Signing; Enforcing Verification And Its Limits |
| 030 / 03 | ImagePullSecrets, ImagePolicyWebhook And Admission Failure Modes | Pull Credentials For Private Registries; The ImagePolicyWebhook Admission Plugin; Admission Failure Modes And Exemptions |
| 030 / capstone | Capstone: Enforce Approved Registries And Digests In One Policy Set | Capstone lab only |
| 040 / 01 | Static Analysis Of Workloads And Images | What Static Analysis Can And Cannot Show; Scanning Manifests With Kubesec; Linting Manifests With KubeLinter; A Release Decision With Image Scans And Pod Security Admission |
| 040 / 02 | Scan Images And Configuration With Trivy | What Trivy Scans: Images, Folders And Configuration; Severity Filters, Unfixed Findings And Exit Codes; Exceptions, Database Freshness And What A Finding Proves |
| 040 / 03 | Enforce Workload Standards With Pod Security Admission | The Pod Security Standards; Namespace Labels, Modes And Versions; Meeting The Restricted Standard, Exemptions And Limits |
| 040 / capstone | Release A Workload Through Analysis, A Scan Gate And Restricted Admission | Advanced lab only |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). No runtime execution is claimed.

## Hands-On Coverage

This course has 12 ungraded module playgrounds and 16 draft independent labs (12 module labs and 4 section capstones). Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Serve Content With A Minimal Runtime |
| 010/02 | Run A Pod With A Restricted Security Context |
| 010/03 | Pin An Image To The Digest The Node Reports |
| 010/capstone | Run A Hardened Minimal Web Server |
| 020/01 | Bind A Package Inventory To A Running Image |
| 020/02 | Record A Structured Package Inventory |
| 020/03 | Give A Service Account Registry Pull Access |
| 020/capstone | Record A Release With Inventory, Digest And Pull Access |
| 030/01 | Enforce An Approved Image Registry |
| 030/02 | Require Image Digests In A Namespace |
| 030/03 | Enforce A Registry Policy And Attach Pull Credentials |
| 030/capstone | Enforce Approved Registries And Digests In One Policy Set |
| 040/01 | Analyze And Correct A Workload Security Document |
| 040/02 | Decide A Scan Gate From Scan Results |
| 040/03 | Enforce The Restricted Pod Security Standard |
| 040/capstone | Release A Workload Through Analysis, A Scan Gate And Restricted Admission |

## Authoring and verification

See [AUTHORING.md](AUTHORING.md) for the lab lifecycle and review workflow, and
[LAB-COVERAGE.md](LAB-COVERAGE.md) for preparation lessons and graded outcomes.
