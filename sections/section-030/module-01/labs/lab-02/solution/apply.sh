#!/usr/bin/env bash
# Reference solution: sign the supplied digest with the training key and verify it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-035-lab-030-01-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
image=$(cat /srv/signing/image.txt)
COSIGN_PASSWORD=training-password cosign sign --yes --use-signing-config=false --key /srv/signing/training.key --tlog-upload=false --allow-insecure-registry "$image"
cosign verify --key /srv/signing/training.pub --insecure-ignore-tlog=true --allow-insecure-registry "$image"
