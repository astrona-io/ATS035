# Teaching and assessment review

The course has teaching material for its registered lab tasks, but its readings cover a broader set of skills than its graders. Passing all environment tests proves the implemented lifecycles; it does not establish complete practical coverage of every learning objective.

`TEACHING-COVERAGE.yaml` names the preparation set for every lab. `LAB-COVERAGE.md` renders both directions: lab to preparation and reading to assessment. A preparation link means the reading teaches something used by that task, not that every operation in the reading is graded. The additional-reading list makes material without a module assessment visible. Capstones combine selected skills and do not silently count as coverage of every reading.

## Live assessment additions

New QEMU labs build and inspect a minimal image, run Trivy against a fresh verified database snapshot, and sign and verify an immutable registry digest. The pull-access lab now uses a real authenticated registry and tests both correct and incorrect credentials.

## Remaining practical gaps and boundaries

- The inventory labs read the live Alpine package database; they do not run Syft or inventory every language dependency.
- The static-analysis lab checks field analysis and a repaired Pod, not execution of Kubesec or KubeLinter.
- Cosign uses disposable local keys and a loopback HTTP registry without a transparency log. Keyless identity, provenance verification and signature enforcement at admission remain ungraded.
- Other pull-secret exercises still teach configuration. Authenticated-pull evidence comes specifically from section-020/module-03/labs/lab-01.

## Runtime choice

Use kind for Kubernetes API objects, admission, scheduling and network tests whose required controllers or network plugin are installed. Use QEMU for an independent Linux kernel, host service lifecycle, mandatory access control or kernel event collection. A runtime name or ConfigMap is never proof that its intended runtime or encryption mechanism is active.

Keep each new lab immediately after its preparation reading. Preserve the existing PR for this repository, push separate commits, and leave merging to the reviewer.
