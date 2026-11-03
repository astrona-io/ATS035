import base64
secret=get('secret','registry-credentials')
config=json.loads(base64.b64decode(secret['data']['.dockerconfigjson']))
entry=config['auths']['registry.example.test']
assert entry['username']=='builder' and entry['password']=='s3cret-pull-token', 'Store the given registry credential'
assert base64.b64decode(entry['auth']).decode()=='builder:s3cret-pull-token', 'The auth field must encode user:password'
account=get('serviceaccount','probe-runner')
assert [item['name'] for item in account.get('imagePullSecrets',[])]==['registry-credentials'], 'Attach the secret to the service account'
pod=get('pod','release-check')
assert [item['name'] for item in pod['spec'].get('imagePullSecrets',[])]==['registry-credentials'], 'The pod must receive the pull secret through its service account'
