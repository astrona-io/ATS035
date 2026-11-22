# Run by testing/check.py, which provides wants(), command(), kubectl() and DIRECTORY.
NAMESPACE_UNDER_TEST = 'hangar-035-040-03-02'

if wants('baseline-enforced'):
    rejected = command(['kubectl', 'apply', '--dry-run=server', '-f', str(DIRECTORY / 'privileged-check.yaml')], success=False)
    assert rejected.returncode != 0 and 'violates PodSecurity "baseline:v1.35"' in rejected.stdout + rejected.stderr, 'enforce=baseline at v1.35 must reject a privileged pod in ' + NAMESPACE_UNDER_TEST
    admitted = command(['kubectl', 'apply', '--dry-run=server', '-f', str(DIRECTORY / 'plain-check.yaml')], success=False)
    assert admitted.returncode == 0, 'A pod that meets baseline must be admitted in ' + NAMESPACE_UNDER_TEST
    assert 'would violate PodSecurity "restricted:v1.35"' in admitted.stderr, 'warn=restricted at v1.35 must return a warning for a pod that only meets baseline'
    for name in ('privileged-check', 'plain-check'):
        assert kubectl('-n', NAMESPACE_UNDER_TEST, 'get', 'pod', name, '--ignore-not-found', '-o', 'name') == '', 'Do not create the pod ' + name

if wants('cargo-loader-running'):
    pods = json.loads(kubectl('-n', NAMESPACE_UNDER_TEST, 'get', 'pods', '-l', 'app=cargo-loader', '-o', 'json'))['items']
    assert any(pod['status'].get('phase') == 'Running' and not pod['metadata'].get('deletionTimestamp') for pod in pods), 'No running cargo-loader pod'
