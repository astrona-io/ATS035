ENFORCED = 'starfleet-035-030-02-02'
EXEMPT = 'outpost-035-030-02-02'
DIGEST = '@sha256:' + 'a' * 64
APPROVED_PINNED = 'registry.starfleet.test/scout' + DIGEST
APPROVED_TAG = 'registry.starfleet.test/scout:1.0'
OTHER_PINNED = 'docker.io/library/busybox' + DIGEST
LOOKALIKE_PINNED = 'registry.starfleet.test.example.com/scout' + DIGEST
REGISTRY_MESSAGE = 'must come from registry.starfleet.test'
DIGEST_MESSAGE = 'must be referenced by digest'


def dry_run(name, namespace, image, **spec):
    """Server-side dry run of a one-container pod; returns the CompletedProcess."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': namespace},
           'spec': {'restartPolicy': 'Never', 'containers': [{'name': 'app', 'image': image, 'command': ['sh', '-c', 'sleep 3600']}], **spec}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-o', 'json', '-f', '-'],
                          input=json.dumps(pod), capture_output=True, text=True, timeout=15)


def rejected_with(result, wanted, unwanted, rule):
    assert result.returncode != 0 and wanted in result.stderr, rule + ' must be rejected with the message containing: ' + wanted
    assert unwanted not in result.stderr, rule + ' breaks only one rule, so the error must not contain: ' + unwanted


def enforced_label():
    return get('namespace', ENFORCED, namespace=None)['metadata'].get('labels', {}).get('training.astrona.io/release-gate')


# Guard: the exempt namespace keeps admitting any pod.
exempt = dry_run('exempt-check', EXEMPT, 'docker.io/library/busybox:1.37.0')
assert exempt.returncode == 0, 'A tag-only pod in ' + EXEMPT + ' must still be accepted'

if wants('registry-rule'):
    rejected_with(dry_run('other-registry', ENFORCED, OTHER_PINNED), REGISTRY_MESSAGE, DIGEST_MESSAGE, 'A pinned image from docker.io')
    rejected_with(dry_run('lookalike', ENFORCED, LOOKALIKE_PINNED), REGISTRY_MESSAGE, DIGEST_MESSAGE, 'A pinned image from registry.starfleet.test.example.com')
if wants('digest-rule'):
    rejected_with(dry_run('tag-only', ENFORCED, APPROVED_TAG), DIGEST_MESSAGE, REGISTRY_MESSAGE, 'A tag-only image from the approved registry')
    init = [{'name': 'prepare', 'image': APPROVED_TAG, 'command': ['sh', '-c', 'true']}]
    rejected_with(dry_run('tag-init', ENFORCED, APPROVED_PINNED, initContainers=init), DIGEST_MESSAGE, REGISTRY_MESSAGE, 'A tag-only init container from the approved registry')
if wants('compliant-accepted'):
    assert enforced_label() == 'enforced', 'Label ' + ENFORCED + ' with training.astrona.io/release-gate=enforced'
    result = dry_run('compliant', ENFORCED, APPROVED_PINNED)
    assert result.returncode == 0, 'A pod with a pinned image from registry.starfleet.test must be accepted in ' + ENFORCED
if wants('running-pods-checked'):
    import re
    pods = json.loads(kubectl('-n', ENFORCED, 'get', 'pods', '-o', 'json'))['items']
    breaking = sorted(
        pod['metadata']['name'] for pod in pods
        if not all(image.startswith('registry.starfleet.test/') and re.search('@sha256:[a-f0-9]{64}$', image)
                   for image in [c['image'] for c in pod['spec']['containers'] + pod['spec'].get('initContainers', [])]))
    assert not breaking, 'Admission does not check running pods; remove the pods that break the policy: ' + ', '.join(breaking)
