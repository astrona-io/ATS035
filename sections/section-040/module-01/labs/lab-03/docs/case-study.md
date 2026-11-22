---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Starting Environment

The namespace `starfleet-035-040-01-03` has the Deployment `score-probe`, which runs a privileged BusyBox container as root, with no resource settings. The pod `scanner` runs Kubesec 2.15.0. Kubesec reads the Kubernetes schemas from its image, so it needs no network access.

Scan a live Deployment with Kubesec inside the cluster, raise its score by fixing the findings, and record the final score.
