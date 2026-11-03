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
assert get('configmap', 'scan-gate')['data'] == GATE, 'The gate must match the supplied scan results and ignore list'
