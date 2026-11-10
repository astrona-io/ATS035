#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-playground-040-03}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
if output="$(kubectl -n hangar apply --dry-run=server -f "$lab_directory/testing/unrestricted-reader.yaml" 2>&1)"; then
  printf 'The unrestricted pod was accepted\n' >&2
  exit 1
fi
case "$output" in
  *"violates PodSecurity"*) printf 'The unrestricted pod was rejected as required\n' ;;
  *) printf 'The request failed for another reason: %s\n' "$output" >&2; exit 1 ;;
esac
