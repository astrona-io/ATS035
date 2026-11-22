# Run by testing/check.py, which provides wants(), get(), command(), kubectl() and NAMESPACE.
EXCEPTION = 'ignore-check.kube-linter.io/no-read-only-root-fs'
IMAGE = 'docker.io/library/busybox:1.37.0'


def linter_annotations(deployment):
    """Every KubeLinter annotation on the Deployment and on its pod template."""
    template = deployment['spec']['template'].get('metadata', {}).get('annotations', {})
    own = deployment['metadata'].get('annotations', {})
    return sorted(key for key in {**template, **own} if 'kube-linter.io/' in key)


if wants('lint-clean'):
    deployment = get('deployment', 'lint-probe')
    extra = [key for key in linter_annotations(deployment) if key != EXCEPTION]
    assert not extra, 'Only the no-read-only-root-fs check may be excepted, found: ' + ', '.join(extra)
    deployment.pop('status', None)
    deployment['metadata'].pop('managedFields', None)
    # The grader lints the live object itself with the team configuration.
    lint = subprocess.run(['kubectl', '-n', NAMESPACE, 'exec', '-i', 'linter', '--', '/kube-linter', 'lint',
                           '--config', '/policy/kube-linter.yaml', '--format', 'json', '-'],
                          input=json.dumps(deployment), capture_output=True, text=True, timeout=60)
    if lint.returncode != 0:
        try:
            checks = sorted({item.get('Check', 'unknown') for item in json.loads(lint.stdout).get('Reports') or []})
        except (ValueError, AttributeError):
            checks = []
        detail = ', '.join(checks) if checks else (lint.stderr.strip()[-300:] or 'no report')
        assert False, 'KubeLinter reports findings for the live lint-probe Deployment: ' + detail

if wants('scoped-exception'):
    deployment = get('deployment', 'lint-probe')
    reason = deployment['metadata'].get('annotations', {}).get(EXCEPTION, '')
    assert reason.strip(), 'Record the ' + EXCEPTION + ' annotation on the lint-probe Deployment'
    before, marker, owner = reason.partition('owner:')
    assert marker and before.strip(' ;,.') and owner.strip(), 'The exception value needs a reason and then "owner: <team>"'

if wants('hardened-rollout'):
    deployment = get('deployment', 'lint-probe')
    status = deployment.get('status', {})
    replicas = deployment['spec'].get('replicas', 1)
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'], 'The current lint-probe generation has not been observed'
    assert status.get('updatedReplicas', 0) == replicas and status.get('availableReplicas', 0) == replicas, 'The lint-probe rollout is incomplete'
    assert deployment['spec']['template']['spec']['containers'][0].get('image') == IMAGE, 'The lint-probe container must use ' + IMAGE
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=lint-probe', '-o', 'json'))['items']
    running = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp') and pod['status'].get('phase') == 'Running']
    assert running, 'No running lint-probe pod'
    for pod in running:
        name = pod['metadata']['name']
        assert pod['spec']['containers'][0].get('image') == IMAGE, name + ' still runs an old image'
        user = command(['kubectl', '-n', NAMESPACE, 'exec', name, '--', 'id', '-u'], success=False)
        assert user.stdout.strip() == '10001', name + ' must run as the numeric user 10001'
        state = command(['kubectl', '-n', NAMESPACE, 'exec', name, '--', 'cat', '/tmp/last-run'], success=False)
        assert state.returncode == 0 and state.stdout.strip(), name + ' has not written /tmp/last-run'
