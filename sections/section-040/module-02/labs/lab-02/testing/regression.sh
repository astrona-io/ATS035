#!/usr/bin/env bash
set -euo pipefail
sudo python3 /opt/astrona-live/check.py fresh-scan
sudo python3 /opt/astrona-live/check.py release-decision
sudo cp /srv/scan/report.json /tmp/report.solved.json
sudo python3 - <<'EDIT'
import json,pathlib
p=pathlib.Path('/srv/scan/report.json');r=json.loads(p.read_text());r['Metadata']['ImageID']='sha256:incorrect';p.write_text(json.dumps(r))
EDIT
set +e
output=$(sudo python3 /opt/astrona-live/check.py fresh-scan); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Scan the supplied live image ID' ]]
sudo cp /tmp/report.solved.json /srv/scan/report.json
sudo cp /srv/scan/decision.json /tmp/decision.solved.json
sudo python3 - <<'EDIT'
import json,pathlib
p=pathlib.Path('/srv/scan/decision.json');r=json.loads(p.read_text());r['high_critical']+=1;p.write_text(json.dumps(r))
EDIT
set +e
output=$(sudo python3 /opt/astrona-live/check.py release-decision); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Bind the complete release decision to the current image and database' ]]
sudo cp /tmp/decision.solved.json /srv/scan/decision.json
