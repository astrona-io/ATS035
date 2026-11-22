# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible.

## Live assessment additions

New QEMU labs build and inspect a minimal image, run Trivy against a fresh verified database snapshot, and sign and verify an immutable registry digest. The pull-access lab now uses a real authenticated registry and tests both correct and incorrect credentials.

## Remaining practical gaps and boundaries

- The first two inventory labs read the live Alpine package database. The Syft lab (section-020/module-01/labs/lab-03) runs a pinned Syft image in a Job against the root file system of the running image and compares the CycloneDX packages with the Alpine database. No lab inventories language dependencies or grades a VEX document made by a tool.
- The workload-document lab checks field analysis and a repaired Pod without running a tool. The Kubesec lab (section-040/module-01/labs/lab-03) and the KubeLinter lab (section-040/module-01/labs/lab-02) run pinned tool images in the cluster against the live Deployment.
- Cosign uses disposable local keys and a loopback HTTP registry without a transparency log. Keyless identity, provenance verification and signature enforcement at admission remain ungraded.
- Other pull-secret exercises still teach configuration. Authenticated-pull evidence comes specifically from section-020/module-03/labs/lab-01.

## Skills from the removed section capstones

The four section capstones were removed so that every graded lab follows the reading it practises, as in ATS034. Each capstone combined skills from its section. The module labs still grade these skills:

- Section 010: a ConfigMap served by BusyBox `httpd` (section-010/module-01/labs/lab-01), a restricted security context (section-010/module-02/labs/lab-01) and a digest pin read from the node (section-010/module-03/labs/lab-01).
- Section 020: an Alpine package inventory bound to the running image ID (section-020/module-01/labs/lab-01), a CycloneDX record (section-020/module-02/labs/lab-01) and a pull Secret attached to a ServiceAccount with a fresh authenticated pull (section-020/module-03/labs/lab-01).
- Section 030: an approved-registry ValidatingAdmissionPolicy (section-030/module-01/labs/lab-01), a digest ValidatingAdmissionPolicy that leaves an unlabelled namespace admitted (section-030/module-02/labs/lab-01) and a Deny binding with pull credentials (section-030/module-03/labs/lab-01).
- Section 040: workload findings recorded without deploying (section-040/module-01/labs/lab-01), a scan gate (section-040/module-02/labs/lab-01) and restricted Pod Security Admission with a rejected privileged Pod (section-040/module-03/labs/lab-01).

The former capstone gaps are graded again:

- The separate `imageDigest` key (section-020/module-02/labs/lab-02).
- One ValidatingAdmissionPolicy with two validations, separate messages and an unchanged `exempt` namespace (section-030/module-02/labs/lab-02).
- CPU and memory requests and a memory limit on a Deployment, and a Service on port 80 that targets the named port `http`, reached by name from the `shuttle` Pod (section-010/module-03/labs/lab-03).
- One namespace that combines the findings with the `imageTag` key, the scan gate and the restricted Pod (section-040/module-03/labs/lab-03).

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
