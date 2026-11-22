#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-lab-020-03-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$lab_directory/bootstrap/manifests/start.yaml"
kubectl -n outpost-035-020-03-02 wait --for=condition=Ready pod/drifter --timeout=120s
# The scout pod must show the failed pull that the task asks the learner to diagnose.
for attempt in $(seq 1 36); do
  reason=$(kubectl -n starfleet-035-020-03-02 get pods -l app=scout -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}')
  case "$reason" in
    *ErrImagePull*|*ImagePullBackOff*) echo "scout pod is waiting with $reason"; exit 0 ;;
  esac
  sleep 5
done
printf 'The scout pod did not reach a failed image pull within three minutes\n' >&2
exit 1
