# Curriculum Coverage

Exam: Certified Kubernetes Security Specialist (CKS). Domain: Supply Chain Security (20%).

The [official objectives](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/) were checked on 2026-10-11. Teaching structure is independently authored and does not add official requirements.

| Section | Official objective | Modules |
| --- | --- | --- |
| 010 | Minimize base image footprint | 1 |
| 020 | Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories) | 1 |
| 030 | Secure your supply chain (permitted registries, sign and validate artifacts, etc.) | 1 |
| 040 | Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter) | 1 |

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize The Base Image Footprint | Layers, Tags And Digests; Multi-Stage Builds And Minimal Base Images; Hardening A Dockerfile; Running Minimal Images In A Cluster |
| 020 / 01 | Understand The Software Supply Chain | Stages, Trust Boundaries And Evidence; Software Bills Of Materials With Syft; Vulnerability Scanning With Trivy; CI/CD Pipelines And Artifact Repositories |
| 030 / 01 | Admission Control, Permitted Registries And Signed Images | The Admission Pipeline And ValidatingAdmissionPolicy; Enforcing Permitted Registries; Policy Engines And Admission Webhooks; Signing And Verifying Images With cosign |
| 040 / 01 | Static Analysis Of Workloads And Images | What Static Analysis Can And Cannot Show; Scanning Manifests With Kubesec; Linting Manifests With KubeLinter; A Release Decision With Image Scans And Pod Security Admission |

AUTHORING.yaml records measurable goals and adaptation sources. Every objective retains its section ID. All technical readings remain draft. Question banks are separate from the reading manifest and follow their declared summaries. Each module has a playground, a graded lab and a knowledge check; no runtime validation is claimed.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Serve Content With A Minimal Runtime |
| 020/01 | Bind A Package Inventory To A Running Image |
| 030/01 | Enforce An Approved Image Registry |
| 040/01 | Analyze And Correct A Workload Security Document |
