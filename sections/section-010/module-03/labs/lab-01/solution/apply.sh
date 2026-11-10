#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-010-03-01}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"

image_id="$(kubectl -n starfleet-035-010-03-01 get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}')"
image_digest="${image_id##*@sha256:}"
if [[ "$image_digest" == "$image_id" ]]; then
  printf 'The node did not report a repository digest for the shuttle pod\n' >&2
  exit 1
fi
sed "s/<DIGEST>/${image_digest}/" "$solution_directory/pod-pinned-runner.yaml.template" | kubectl apply -f -
kubectl -n starfleet-035-010-03-01 wait --for=condition=Ready pod/pinned-runner --timeout=180s
