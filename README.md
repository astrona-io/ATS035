# Supply Chain Security (ATS035)

Certified Kubernetes Security Specialist (CKS): Supply Chain Security, worth 20% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Technical content remains draft. Private playgrounds and draft graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize The Base Image Footprint | Layers, Tags And Digests; Multi-Stage Builds And Minimal Base Images; Hardening A Dockerfile; Running Minimal Images In A Cluster |
| 020 / 01 | Understand The Software Supply Chain | Stages, Trust Boundaries And Evidence; Software Bills Of Materials With Syft; Vulnerability Scanning With Trivy; CI/CD Pipelines And Artifact Repositories |
| 030 / 01 | Admission Control, Permitted Registries And Signed Images | The Admission Pipeline And ValidatingAdmissionPolicy; Enforcing Permitted Registries; Policy Engines And Admission Webhooks; Signing And Verifying Images With cosign |
| 040 / 01 | Static Analysis Of Workloads And Images | What Static Analysis Can And Cannot Show; Scanning Manifests With Kubesec; Linting Manifests With KubeLinter; A Release Decision With Image Scans And Pod Security Admission |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). No runtime execution is claimed.

## Hands-On Coverage

This course has 4 ungraded module playgrounds and 4 draft independent labs. Tasks and solutions are registered around each lab immediately after its teaching reading. Static configuration, shell/Python/YAML, parser, lifecycle and offline grader checks pass. Live execution remains pending because the session cannot access Podman; installed CLI configuration validation is separately blocked by its maintenance lock.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Serve Content With A Minimal Runtime |
| 020/01 | Bind A Package Inventory To A Running Image |
| 030/01 | Enforce An Approved Image Registry |
| 040/01 | Analyze And Correct A Workload Security Document |
