import json
import subprocess
import tempfile
from pathlib import Path

CONTEXT = "kind-astro-ats-035-capstone-040"


def run(*args):
    result = subprocess.run(args, check=True, text=True, capture_output=True, timeout=30)
    return result.stdout.strip()


assert run('kubectl', 'config', 'current-context') == CONTEXT, 'Select the private environment'
CONFIG = {name: json.loads(run('kubectl', '-n', 'bay', 'get', 'configmap', name, '-o', 'json'))['data'] for name in ('analysis-source', 'scan-results', 'scan-exceptions')}
workload = json.loads(CONFIG['analysis-source']['workload.json'])
container = workload['spec']['containers'][0]
security = container.get('securityContext', {})
image_name = container['image'].rsplit('/', 1)[-1]
FINDINGS = {
    'privileged': str(security.get('privileged', False)).lower(),
    'runAsNonRoot': 'missing' if 'runAsNonRoot' not in workload['spec'].get('securityContext', {}) else 'present',
    'allowPrivilegeEscalation': 'missing' if 'allowPrivilegeEscalation' not in security else 'present',
    'imageTag': image_name.split(':', 1)[1] if ':' in image_name else 'latest',
}
results = json.loads(CONFIG['scan-results']['results.json'])
ignored = {line.strip() for line in CONFIG['scan-exceptions']['trivyignore.txt'].splitlines() if line.strip() and not line.startswith('#')}
blocking, waived, unfixed = [], [], []
for target in results['Results']:
    for finding in target.get('Vulnerabilities', []):
        if finding['Severity'] not in ('HIGH', 'CRITICAL'):
            continue
        identifier = finding['VulnerabilityID']
        if not finding.get('FixedVersion'):
            unfixed.append(identifier)
        elif identifier in ignored:
            waived.append(identifier)
        else:
            blocking.append(identifier)
GATE = {'decision': 'fail' if blocking else 'pass', 'blocking': ','.join(sorted(blocking)), 'waived': ','.join(sorted(waived)),
        'unfixed': ','.join(sorted(unfixed)), 'severity': 'HIGH,CRITICAL', 'ignoreUnfixed': 'true'}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    for config_name, values in (('analysis-findings', FINDINGS), ('scan-gate', GATE)):
        source = Path(temporary) / (config_name + '.json')
        source.write_text(json.dumps({'apiVersion': 'v1', 'kind': 'ConfigMap', 'metadata': {'name': config_name, 'namespace': 'bay'}, 'data': values}))
        run('kubectl', 'apply', '-f', str(source))
