#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-010-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
solution_directory="$lab_directory/solution"
namespace=starfleet-035-010-02-02

# Read the facts from a running probe pod, then fill the report template.
probe_loader="$(kubectl -n "$namespace" exec deploy/probe -- sh -c 'ls /lib/ld-musl*')"
probe_packages="$(kubectl -n "$namespace" exec deploy/probe -- sh -c 'apk info | wc -l')"
sed -e "s|<LOADER>|$probe_loader|" -e "s|<PACKAGES>|$probe_packages|" \
  "$solution_directory/configmap-base-image-report.yaml" | kubectl apply -f -

kubectl apply -f "$solution_directory/deployment-beacon.yaml"
kubectl -n "$namespace" rollout status deployment/beacon --timeout=180s
