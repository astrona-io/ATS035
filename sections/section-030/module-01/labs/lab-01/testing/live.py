def dry_run(name, namespace, image, **spec):
    """Server-side dry run of a one-container pod; returns the CompletedProcess."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': namespace},
           'spec': {'restartPolicy': 'Never', 'containers': [{'name': 'app', 'image': image, 'command': ['sh', '-c', 'sleep 3600']}], **spec}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-o', 'json', '-f', '-'],
                          input=json.dumps(pod), capture_output=True, text=True, timeout=15)


if wants('unapproved-rejected'):
    result = dry_run('blocked-reader', 'approved-images-035-030-01-01', 'unapproved.example/reader:v1')
    assert result.returncode != 0 and 'only the training approved registry prefix' in result.stderr, 'A pod with unapproved.example/reader:v1 in approved-images-035-030-01-01 must be rejected with the policy message'
