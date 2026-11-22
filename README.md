<p align="center">
  <a href="https://astrona.io/courses/certified-kubernetes-security-specialist">
    <img src="https://astrona.io/courses/certified-kubernetes-security-specialist/domains/ATS035.svg" alt="ATS035: Supply Chain Security, part of the Certified Kubernetes Security Specialist course on Astrona" width="100%">
  </a>
</p>

# Supply Chain Security (ATS035)

Certified Kubernetes Security Specialist (CKS): Supply Chain Security, worth 20% of the official curriculum. This course belongs to ATP007.

Developed reading explains mechanisms, responsible components, examples and limits. Every section has an introduction and every module closes with a summary. Reusable YAML checks contain 5–15 questions per bank. Private playgrounds and graded labs are included.

## Course Outline

| Section / module | Module | Teaching files |
| --- | --- | --- |
| 010 / 01 | Minimize The Base Image Footprint | Layers, Tags And Digests; Multi-Stage Builds And Minimal Base Images; Hardening A Dockerfile; Running Minimal Images In A Cluster; Build And Inspect The Final Image |
| 010 / 02 | Compare Base Images And Their Attack Surface | What Each Base Image Contains; Measure What A Running Container Can Reach |
| 010 / 03 | Keep Images Small And Fresh Over Time | Pin Images By Digest And Keep The Pin Current; Pull Policy, Rebuild Cadence And Size Budgets; Resource Budgets And A Service For A Small Image |
| 020 / 01 | Understand The Software Supply Chain | Stages, Trust Boundaries And Evidence; Software Bills Of Materials With Syft; Vulnerability Scanning With Trivy; CI/CD Pipelines And Artifact Repositories; Make An SBOM Of A Running Image In The Cluster |
| 020 / 02 | Generate And Read Software Bills Of Materials | Reading SPDX And CycloneDX Documents; Matching An SBOM To Vulnerabilities And An Image Digest |
| 020 / 03 | Provenance, Artifact Repositories And Pull Access | Registries, Repositories And Who May Push Or Pull; Pull Secrets And Service Accounts; Prove An Image Pull Uses Registry Credentials; Build Provenance And SLSA Levels |
| 030 / 01 | Admission Control, Permitted Registries And Signed Images | The Admission Pipeline And ValidatingAdmissionPolicy; Enforcing Permitted Registries; Policy Engines And Admission Webhooks; Signing And Verifying Images With cosign; Verify Who Signed An Image Digest |
| 030 / 02 | Require Image Digests And Verify Signatures | A Digest Rule With ValidatingAdmissionPolicy; Signatures, Attestations And Keyless Signing; Enforcing Verification And Its Limits |
| 030 / 03 | ImagePullSecrets, ImagePolicyWebhook And Admission Failure Modes | Pull Credentials For Private Registries; The ImagePolicyWebhook Admission Plugin; Admission Failure Modes And Exemptions |
| 040 / 01 | Static Analysis Of Workloads And Images | What Static Analysis Can And Cannot Show; Scanning Manifests With Kubesec; Linting Manifests With KubeLinter; A Release Decision With Image Scans And Pod Security Admission |
| 040 / 02 | Scan Images And Configuration With Trivy | What Trivy Scans: Images, Folders And Configuration; Severity Filters, Unfixed Findings And Exit Codes; Exceptions, Database Freshness And What A Finding Proves; Use A Fresh Scan As Release Evidence |
| 040 / 03 | Enforce Workload Standards With Pod Security Admission | The Pod Security Standards; Namespace Labels, Modes And Versions; Meeting The Restricted Standard, Exemptions And Limits; Release A Workload Through Analysis, A Scan Gate And Restricted Admission |

## Author Review

See [curriculum coverage](CURRICULUM.md), [primary sources](SOURCES.md), [question-bank documentation](ASSESSMENTS.md) and [contribution instructions](CONTRIBUTING.md). Runtime results are recorded in the PR and GitHub Actions.

## Hands-On Coverage

This course has 12 ungraded module playgrounds, all on kind, and 28 graded labs (25 on kind, 3 on a qemu VM). Each lab sits right after the reading it practises, with its task before and its solution after. Every lab passed `astrona validate` and `astrona test` on its own runtime, and every playground started with `scripts/ci/test-playground.sh`.

| Module | Labs in teaching order |
| --- | --- |
| 010/01 | Serve Content With A Minimal Runtime; Build A Minimal Runtime Image |
| 010/02 | Compare Base Images And Move A Workload To The Smaller One; Run A Pod With A Restricted Security Context |
| 010/03 | Pin An Image To The Digest The Node Reports; Choose An Image Pull Policy From What The Node Holds; Run A Pinned Web Server With A Resource Budget And A Service |
| 020/01 | Record The Images That Run In A Namespace; Bind A Package Inventory To A Running Image; Make An SBOM Of A Running Image With Syft |
| 020/02 | Record A Structured Package Inventory; Bind An SBOM And A VEX Statement To An Image Digest |
| 020/03 | Diagnose A Failed Image Pull And Record The Resolved Image; Repair Authenticated Image Pulls |
| 030/01 | Enforce An Approved Image Registry; Sign And Verify An Immutable Image |
| 030/02 | Require Image Digests In A Namespace; Combine Registry And Digest Rules In One Admission Policy |
| 030/03 | Make ImagePolicyWebhook Fail Closed; Enforce A Registry Policy And Attach Pull Credentials |
| 040/01 | Score A Live Deployment With Kubesec; Lint A Live Deployment With KubeLinter; Analyze And Correct A Workload Security Document |
| 040/02 | Decide A Scan Gate From Scan Results; Scan An Image And Bind The Release Decision |
| 040/03 | Enforce Baseline And Warn On Restricted With Pod Security Admission; Enforce The Restricted Pod Security Standard; Release A Workload Through Analysis, A Scan Gate And Restricted Admission |

## Authoring and verification

See [AUTHORING.md](AUTHORING.md) for the lab lifecycle and review workflow, and
[LAB-COVERAGE.md](LAB-COVERAGE.md) for preparation lessons and graded outcomes.

See [lesson and lab links](LAB-COVERAGE.md) and [remaining practical gaps](COVERAGE-REVIEW.md) for the current assessment scope.
