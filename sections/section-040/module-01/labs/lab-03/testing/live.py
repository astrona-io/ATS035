# Run by testing/check.py, which provides wants(), get(), command(), kubectl() and NAMESPACE.
IMAGE = 'docker.io/library/busybox:1.37.0'
MINIMUM = 10


def kubesec_report():
    """Scan the live score-probe Deployment with Kubesec in the scanner pod."""
    manifest = command(['kubectl', '-n', NAMESPACE, 'get', 'deployment', 'score-probe', '-o', 'yaml'], success=False)
    assert manifest.returncode == 0, 'Missing deployment score-probe in namespace ' + NAMESPACE
    scan = subprocess.run(['kubectl', '-n', NAMESPACE, 'exec', '-i', 'scanner', '--', 'kubesec', 'scan', '-'],
                          input=manifest.stdout, capture_output=True, text=True, timeout=60)
    try:
        report = json.loads(scan.stdout)[0]
    except (ValueError, IndexError, KeyError, TypeError):
        assert False, 'Kubesec returned no report: ' + (scan.stderr.strip()[-300:] or 'no output')
    assert report.get('valid') is True, 'Kubesec could not read the live score-probe Deployment: ' + str(report.get('message', ''))
    return report


if wants('kubesec-passes'):
    report = kubesec_report()
    critical = sorted(item.get('id', 'unknown') for item in report.get('scoring', {}).get('critical') or [])
    assert not critical, 'Kubesec reports critical findings for score-probe: ' + ', '.join(critical)
    assert report.get('score', 0) >= MINIMUM, 'The Kubesec score of score-probe is ' + str(report.get('score')) + ', below ' + str(MINIMUM)

if wants('score-recorded'):
    data = get('configmap', 'kubesec-report').get('data', {})
    assert data.get('object', '').strip() == 'deployment/score-probe', 'Set the object key of kubesec-report to deployment/score-probe'
    score = kubesec_report().get('score')
    assert data.get('score', '').strip() == str(score), 'The score key of kubesec-report must hold the current Kubesec score, ' + str(score)

if wants('hardened-rollout'):
    deployment = get('deployment', 'score-probe')
    status = deployment.get('status', {})
    replicas = deployment['spec'].get('replicas', 1)
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'], 'The current score-probe generation has not been observed'
    assert status.get('updatedReplicas', 0) == replicas and status.get('availableReplicas', 0) == replicas, 'The score-probe rollout is incomplete'
    assert deployment['spec']['template']['spec']['containers'][0].get('image') == IMAGE, 'The score-probe container must use ' + IMAGE
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=score-probe', '-o', 'json'))['items']
    running = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp') and pod['status'].get('phase') == 'Running']
    assert running, 'No running score-probe pod'
    for pod in running:
        name = pod['metadata']['name']
        assert pod['spec']['containers'][0].get('image') == IMAGE, name + ' still runs an old image'
        user = command(['kubectl', '-n', NAMESPACE, 'exec', name, '--', 'id', '-u'], success=False)
        assert user.stdout.strip() == '10001', name + ' must run as the numeric user 10001'
        state = command(['kubectl', '-n', NAMESPACE, 'exec', name, '--', 'cat', '/tmp/last-run'], success=False)
        assert state.returncode == 0 and state.stdout.strip(), name + ' has not written /tmp/last-run'
