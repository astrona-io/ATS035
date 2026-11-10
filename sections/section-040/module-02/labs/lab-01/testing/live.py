CONFIG = {name: get('configmap', name)['data'] for name in ('scan-results', 'scan-exceptions')}
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


def gate_has(*keys):
    data = get('configmap', 'scan-gate').get('data', {})
    for key in keys:
        assert data.get(key) == GATE[key], 'Set ' + key + ' in scan-gate from the supplied scan results and ignore list'
    return data


if wants('gate-decision'):
    gate_has('decision', 'blocking')
if wants('gate-exceptions'):
    gate_has('waived', 'unfixed')
if wants('gate-settings'):
    data = gate_has('severity', 'ignoreUnfixed')
    assert set(data) == set(GATE), 'scan-gate must hold exactly the keys ' + ','.join(sorted(GATE))
