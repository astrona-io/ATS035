---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Starting Environment

The namespace `starfleet-035-020-01-02` runs two `probe` replicas, each with an init container named `prepare`, and the `shuttle` client pod. The namespace `outpost-035-020-01-02` runs the `drifter` pod. No image inventory exists yet.

List every container that runs in a namespace, including init containers, with the image it requested and the image ID that the container runtime resolved.
