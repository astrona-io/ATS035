import base64
if wants('pull-secret'):
    secret = get('secret', 'registry-credentials')
    try:
        config = json.loads(base64.b64decode(secret['data']['.dockerconfigjson']))
        entry = config['auths']['registry.example.test']
    except (KeyError, TypeError, ValueError):
        entry = {}
    assert entry.get('username') == 'builder' and entry.get('password') == 's3cret-pull-token', 'Store the given registry credential for registry.example.test'
    assert base64.b64decode(entry.get('auth', '')).decode() == 'builder:s3cret-pull-token', 'The auth field must encode user:password'
if wants('release-check'):
    pod = get('pod', 'release-check')
    assert [item['name'] for item in pod['spec'].get('imagePullSecrets', [])] == ['registry-credentials'], 'release-check must receive the pull secret through its service account'
