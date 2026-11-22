---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Combine Registry And Digest Rules In One Admission Policy

Solve this question on: `terminal`

Enforce an approved registry and a digest in one ValidatingAdmissionPolicy with a separate message for each rule, apply it to one labelled namespace only, and remove a pod that was admitted before the rule.

Allow about 12 minutes for the tasks. Cluster startup adds time.

## Starting state

The `starfleet` namespace must only run pinned images from the fleet registry, while the `outpost` namespace stays exempt. No admission policy exists yet. The namespace `starfleet-035-030-02-02` runs the pod `legacy-scout` with the image `docker.io/library/busybox:1.37.0`. The namespace `outpost-035-030-02-02` has the label `training.astrona.io/release-gate: exempt` and runs the pod `drifter`.

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-030-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-030-02-02" || exit 1
```

Keep this connection selected. Every command in this lab talks to the API server of this cluster only.

## Tasks

1. Add the label `training.astrona.io/release-gate: enforced` to the namespace `starfleet-035-030-02-02`.
2. Create the ValidatingAdmissionPolicy `release-gate` with `failurePolicy: Fail` for Pod creation and update. It checks every image in `containers`, `initContainers` and `ephemeralContainers` with two validations: the first requires the image to start with `registry.starfleet.test/` and has a message that contains `must come from registry.starfleet.test`; the second requires the image to end in `@sha256:` followed by 64 lowercase hexadecimal characters and has a message that contains `must be referenced by digest`.
3. Bind it with the ValidatingAdmissionPolicyBinding `release-gate`, the single validation action `Deny` and a namespace selector that matches `training.astrona.io/release-gate: enforced`.
4. Find every pod in `starfleet-035-030-02-02` that already runs and breaks one of the two rules, and delete it.

## Constraints

- Do not change the label of `outpost-035-030-02-02`. A tag-only pod there must still be accepted.
- Do not change the `drifter` pod.
- Use server-side dry runs to test the policy. The registry `registry.starfleet.test` does not need to exist for admission.

## How the answer is checked

The grader runs four checks with server-side dry runs in `starfleet-035-030-02-02`. The first sends pinned images from `docker.io` and from `registry.starfleet.test.example.com`, which must be rejected with the registry message and without the digest message. The second sends a tag-only image from `registry.starfleet.test`, once as a container and once as an init container, which must be rejected with the digest message and without the registry message. The third reads the policy, the binding and the namespace label and needs a pinned image from `registry.starfleet.test` to be accepted. The fourth lists the pods in the namespace. In every check, `outpost-035-030-02-02` keeps its label, accepts a tag-only pod, and `drifter` still runs.
