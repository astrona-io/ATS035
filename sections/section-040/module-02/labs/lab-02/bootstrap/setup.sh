#!/usr/bin/env bash
set -euo pipefail
sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl python3 ca-certificates
sudo systemctl enable --now docker
case "$(uname -m)" in
 x86_64) arch=64bit; checksum=bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf ;;
 aarch64) arch=ARM64; checksum=ab9d51f86e6a5fb936f605faff6b593ac51bc378fff4d3e8b9d58358b9c367c3 ;;
 *) exit 2 ;;
esac
curl -fL --retry 3 --max-time 180 "https://github.com/aquasecurity/trivy/releases/download/v0.76.2/trivy_0.76.2_Linux-$arch.tar.gz" -o /tmp/trivy.tar.gz
printf '%s  /tmp/trivy.tar.gz\n' "$checksum" | sha256sum -c -
sudo tar -xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy
sudo docker pull alpine:3.18.0
sudo install -d -m 0777 /srv/scan
sudo install -d /opt/astrona-live /var/cache/trivy-training
sudo trivy image --cache-dir /var/cache/trivy-training --download-db-only --no-progress
sudo sha256sum /var/cache/trivy-training/db/trivy.db /var/cache/trivy-training/db/metadata.json | sudo tee /opt/astrona-live/db.sha256 >/dev/null

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import datetime,json,pathlib,subprocess,sys,tempfile
def run(args,timeout=120): return subprocess.run(args,text=True,capture_output=True,timeout=timeout)
def findings(report):
    return sorted((r['Target'],v['VulnerabilityID'],v['PkgName'],v['InstalledVersion'],v.get('FixedVersion',''),v['Severity']) for r in report.get('Results',[]) for v in r.get('Vulnerabilities',[]))
def check(outcome):
    path=pathlib.Path('/srv/scan/report.json')
    assert path.is_file(), 'Run the image scan and save report.json'
    hashes=run(['sha256sum','-c','/opt/astrona-live/db.sha256'])
    assert hashes.returncode==0, 'Preserve the database snapshot downloaded during bootstrap'
    db=json.loads(pathlib.Path('/var/cache/trivy-training/db/metadata.json').read_text())
    updated=datetime.datetime.fromisoformat(db['UpdatedAt'].replace('Z','+00:00'))
    age=datetime.datetime.now(datetime.timezone.utc)-updated
    if age.total_seconds() < -300 or age.total_seconds()>72*3600: raise RuntimeError('The lab database is outside its 72-hour freshness window; recreate the lab')
    report=json.loads(path.read_text())
    with tempfile.TemporaryDirectory() as temp:
        fresh=temp+'/fresh.json'
        scan=run(['trivy','image','--cache-dir','/var/cache/trivy-training','--skip-db-update','--offline-scan','--image-src','docker','--scanners','vuln','--format','json','--output',fresh,'alpine:3.18.0'])
        if scan.returncode: raise RuntimeError('Fresh Trivy scan failed: '+scan.stderr[-500:])
        expected=json.loads(pathlib.Path(fresh).read_text())
    assert report['Metadata']['ImageID']==expected['Metadata']['ImageID'], 'Scan the supplied live image ID'
    assert report['Metadata']['OS']==expected['Metadata']['OS'] and findings(report)==findings(expected), 'Keep every current vulnerability and its package, version, fix and severity'
    assert [r['Target'] for r in report.get('Results',[])]==[r['Target'] for r in expected.get('Results',[])], 'Keep every scan target including targets with no findings'
    if outcome=='release-decision':
        path=pathlib.Path('/srv/scan/decision.json');assert path.is_file(), 'Write decision.json from the live scan'
        decision=json.loads(path.read_text());count=sum(v[5] in ('HIGH','CRITICAL') for v in findings(expected))
        assert decision=={'image_id':expected['Metadata']['ImageID'],'database_updated_at':db['UpdatedAt'],'high_critical':count,'decision':'block' if count else 'allow'}, 'Bind the complete release decision to the current image and database'
    elif outcome!='fresh-scan': raise RuntimeError('Unknown outcome')

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
