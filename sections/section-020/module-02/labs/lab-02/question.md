---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Bind An SBOM And A VEX Statement To An Image Digest

Solve this question on: `terminal`

Bind an SBOM record to the image digest that runs, and record a VEX statement for a scan finding against that digest instead of the tag.

Allow about 8 minutes for the tasks. Cluster startup adds time.

## Starting state

The namespace `starfleet-035-020-02-02` runs two `probe` replicas from `docker.io/library/python:3.13-alpine`. The ConfigMap `sbom-record` names that tag as its `subject`. The ConfigMap `scan-finding` holds a training finding, `TRAINING-2026-0001`, also recorded against the tag. No VEX statement exists.

The fleet security team reviewed the finding. The affected function is in a module that the `probe` server never imports, so the team wants to record that the running image is not affected.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-02-02" || exit 1
```

Keep this connection selected. Every command in this lab works on this cluster only.

## Tasks

1. Read the `imageID` of the container `probe` in a ready `probe` pod in the namespace `starfleet-035-020-02-02`.
2. Update the ConfigMap `sbom-record`: set `subject` to that `imageID`, and add the key `imageDigest` with the part of the `imageID` after the last `@` (it starts with `sha256:`). Keep `format` and `scope` unchanged.
3. Create the ConfigMap `vex-statement` in the same namespace with the keys `vulnerability` (the value from `scan-finding`), `product` (the `imageDigest` value), `status` (`not_affected`), `justification` (`vulnerable_code_not_in_execute_path`), `author` (who makes the claim, for example `fleet-security-team`) and `reviewBy` (a review date in the form `YYYY-MM-DD`).

## Constraints

- Do not change the `probe` Deployment, its pods, the `shuttle` pod or the ConfigMap `scan-finding`.
- Do not change anything in `outpost-035-020-02-02`.
- The records are stored claims. They are not a signed attestation, and this lab does not run a scanner.

## How the answer is checked

The grader runs three checks against the live pod status. The first checks that `subject` in `sbom-record` equals the `imageID` of a ready `probe` container. The second checks that `imageDigest` is the `sha256:` part of that `imageID`. The third checks every key of `vex-statement`, and that `product` is the live digest rather than the tag.
