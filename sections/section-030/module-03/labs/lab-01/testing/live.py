def dry_run(name, namespace, image, **spec):
    """Server-side dry run of a one-container pod; returns the CompletedProcess."""
    pod = {'apiVersion': 'v1', 'kind': 'Pod', 'metadata': {'name': name, 'namespace': namespace},
           'spec': {'restartPolicy': 'Never', 'containers': [{'name': 'app', 'image': image, 'command': ['sh', '-c', 'sleep 3600']}], **spec}}
    return subprocess.run(['kubectl', 'create', '--dry-run=server', '-o', 'json', '-f', '-'],
                          input=json.dumps(pod), capture_output=True, text=True, timeout=15)


import base64
if wants('binding-deny'):
    result = dry_run('blocked', 'gated-images-035-030-03-01', 'unapproved.example/reader:v1')
    assert result.returncode != 0 and 'image registry is not approved' in result.stderr, 'A pod with unapproved.example/reader:v1 in gated-images-035-030-03-01 must be rejected with the policy message'
if wants('pull-secret'):
    secret = get('secret', 'registry-credentials', namespace='gated-images-035-030-03-01')
    try:
        entry = json.loads(base64.b64decode(secret['data']['.dockerconfigjson']))['auths']['registry.example.com']
    except (KeyError, TypeError, ValueError):
        entry = {}
    assert entry.get('username') == 'reader' and entry.get('password'), 'Store the reader credential for registry.example.com'
if wants('service-account'):
    result = dry_run('approved', 'gated-images-035-030-03-01', 'docker.io/library/busybox:1.37.0', serviceAccountName='deployer')
    assert result.returncode == 0, 'A busybox pod with ServiceAccount deployer must be accepted in gated-images-035-030-03-01'
    secrets = json.loads(result.stdout)['spec'].get('imagePullSecrets', [])
    assert [item['name'] for item in secrets] == ['registry-credentials'], 'Pods with ServiceAccount deployer must receive registry-credentials as an image pull secret'
