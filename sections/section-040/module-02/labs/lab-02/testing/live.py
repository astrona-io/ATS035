# Checks that compare the submitted Trivy report and release decision with a
# fresh scan on the lab VM. check.py runs this file with NODE, node_exec(),
# command() and wants() already defined. The scanner cache belongs to root,
# so Trivy runs with sudo.
import datetime

SCAN = Path('/srv/scan')
CACHE = '/var/cache/trivy-training'
# bootstrap/setup.sh keeps the hashes of the downloaded database here.
HASHES = '/opt/astrona-live/db.sha256'
IMAGE = 'alpine:3.18.0'


def run(*args, timeout=120):
    return subprocess.run(['sudo', *args], capture_output=True, text=True, timeout=timeout)


def findings(report):
    return sorted((result['Target'], item['VulnerabilityID'], item['PkgName'], item['InstalledVersion'], item.get('FixedVersion', ''), item['Severity'])
                  for result in report.get('Results', []) for item in result.get('Vulnerabilities', []))


def check_report():
    """The saved report matches a fresh scan of the supplied image with the lab database."""
    report_path = SCAN / 'report.json'
    assert report_path.is_file(), 'Run the image scan and save report.json'
    assert run('sha256sum', '-c', HASHES).returncode == 0, 'Preserve the database snapshot downloaded during bootstrap'
    database = json.loads(run('cat', CACHE + '/db/metadata.json').stdout)
    updated = datetime.datetime.fromisoformat(database['UpdatedAt'].replace('Z', '+00:00'))
    age = (datetime.datetime.now(datetime.timezone.utc) - updated).total_seconds()
    if age < -300 or age > 72 * 3600:
        raise RuntimeError('The lab database is outside its 72-hour freshness window; recreate the lab')
    report = json.loads(report_path.read_text())
    scan = run('trivy', 'image', '--cache-dir', CACHE, '--skip-db-update', '--offline-scan', '--image-src', 'docker',
               '--scanners', 'vuln', '--format', 'json', '--quiet', IMAGE)
    if scan.returncode:
        raise RuntimeError('Fresh Trivy scan failed: ' + scan.stderr[-500:])
    expected = json.loads(scan.stdout)
    assert report['Metadata']['ImageID'] == expected['Metadata']['ImageID'], 'Scan the supplied live image ID'
    assert report['Metadata']['OS'] == expected['Metadata']['OS'] and findings(report) == findings(expected), 'Keep every current vulnerability and its package, version, fix and severity'
    assert [result['Target'] for result in report.get('Results', [])] == [result['Target'] for result in expected.get('Results', [])], 'Keep every scan target including targets with no findings'
    return expected, database


def check_decision(expected, database):
    """decision.json names the current image, the database time and the complete HIGH/CRITICAL count."""
    decision_path = SCAN / 'decision.json'
    assert decision_path.is_file(), 'Write decision.json from the live scan'
    decision = json.loads(decision_path.read_text())
    count = sum(item[5] in ('HIGH', 'CRITICAL') for item in findings(expected))
    assert decision == {
        'image_id': expected['Metadata']['ImageID'],
        'database_updated_at': database['UpdatedAt'],
        'high_critical': count,
        'decision': 'block' if count else 'allow',
    }, 'Bind the complete release decision to the current image and database'


# A decision only counts when its report is current, so both outcomes start
# with the fresh scan. One scan serves both when the whole lab is graded.
fresh_scan = wants('fresh-scan')
release_decision = wants('release-decision')
if fresh_scan or release_decision:
    expected, database = check_report()
    if release_decision:
        check_decision(expected, database)
