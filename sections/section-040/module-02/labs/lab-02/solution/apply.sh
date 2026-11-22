#!/usr/bin/env bash
# Reference solution: a full offline scan and the decision computed from it.
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kubernetes-admin@astro-ats-035-lab-040-02-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
sudo trivy image --cache-dir /var/cache/trivy-training --skip-db-update --offline-scan --image-src docker --scanners vuln --format json --output /srv/scan/report.json alpine:3.18.0
sudo python3 - <<'DECISION'
import json,pathlib
report=json.loads(pathlib.Path('/srv/scan/report.json').read_text())
db=json.loads(pathlib.Path('/var/cache/trivy-training/db/metadata.json').read_text())
count=sum(v['Severity'] in ('HIGH','CRITICAL') for r in report.get('Results',[]) for v in r.get('Vulnerabilities',[]))
pathlib.Path('/srv/scan/decision.json').write_text(json.dumps({'image_id':report['Metadata']['ImageID'],'database_updated_at':db['UpdatedAt'],'high_critical':count,'decision':'block' if count else 'allow'},indent=2)+'\n')
DECISION
