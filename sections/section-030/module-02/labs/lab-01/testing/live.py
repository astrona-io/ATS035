def dry_run(name, namespace, image, **spec):
    """Server-side dry run of a one-container pod; returns the CompletedProcess."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': namespace},
           'spec': {'restartPolicy': 'Never', 'containers': [{'name': 'app', 'image': image, 'command': ['sh', '-c', 'sleep 3600']}], **spec}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-o', 'json', '-f', '-'],
                          input=json.dumps(pod), capture_output=True, text=True, timeout=15)


DIGEST_IMAGE = 'docker.io/library/busybox@sha256:' + 'a' * 64
TAG_IMAGE = 'docker.io/library/busybox:1.37.0'
outside = dry_run('tag-outside', 'starfleet-035-030-02-01', TAG_IMAGE)
assert outside.returncode == 0, 'A tag-only pod in starfleet-035-030-02-01 must still be accepted'
if wants('tag-rejected'):
    result = dry_run('tag-only', 'pinned-images-035-030-02-01', TAG_IMAGE)
    assert result.returncode != 0 and 'must be referenced by digest' in result.stderr, 'A tag-only pod in pinned-images-035-030-02-01 must be rejected with the policy message'
    result = dry_run('tag-init', 'pinned-images-035-030-02-01', DIGEST_IMAGE,
                     initContainers=[{'name': 'prepare', 'image': TAG_IMAGE, 'command': ['sh', '-c', 'true']}])
    assert result.returncode != 0 and 'must be referenced by digest' in result.stderr, 'A pod with a tag-only init container must be rejected too'
if wants('digest-accepted'):
    labels = get('namespace', 'pinned-images-035-030-02-01', namespace=None)['metadata'].get('labels', {})
    assert labels.get('training.astrona.io/digest-policy') == 'enabled', 'Label pinned-images-035-030-02-01 with training.astrona.io/digest-policy=enabled'
    get('validatingadmissionpolicybinding', 'require-digest', namespace=None)
    result = dry_run('pinned', 'pinned-images-035-030-02-01', DIGEST_IMAGE)
    assert result.returncode == 0, 'A pod pinned by digest must be accepted in pinned-images-035-030-02-01'
