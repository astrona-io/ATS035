# Run by testing/check.py, which provides wants(), get(), command(), kubectl() and NAMESPACE.


def expected_gate():
    """The gate from the supplied scan results and ignore list."""
    results = json.loads(get('configmap', 'scan-results')['data']['results.json'])
    exceptions = get('configmap', 'scan-exceptions')['data']['trivyignore.txt']
    ignored = {line.strip() for line in exceptions.splitlines() if line.strip() and not line.startswith('#')}
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
    return {'decision': 'fail' if blocking else 'pass', 'blocking': ','.join(sorted(blocking)), 'waived': ','.join(sorted(waived)),
            'unfixed': ','.join(sorted(unfixed)), 'severity': 'HIGH,CRITICAL', 'ignoreUnfixed': 'true'}


if wants('restricted-namespace'):
    rejected = command(['kubectl', '-n', NAMESPACE, 'apply', '--dry-run=server', '-f', str(DIRECTORY / 'unsafe-source.json')], success=False)
    assert rejected.returncode != 0 and 'violates PodSecurity' in rejected.stdout + rejected.stderr, 'The namespace must reject the unsafe document'
    assert kubectl('-n', NAMESPACE, 'get', 'pod', 'unsafe-source', '--ignore-not-found', '-o', 'name') == '', 'Do not deploy the unsafe document'

if wants('scan-gate'):
    gate = get('configmap', 'scan-gate').get('data', {})
    wanted = expected_gate()
    wrong = sorted(key for key in set(wanted) | set(gate) if gate.get(key) != wanted.get(key))
    assert not wrong, 'The scan-gate keys differ from the supplied scan results and ignore list: ' + ', '.join(wrong)
