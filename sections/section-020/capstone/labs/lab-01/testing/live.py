import base64
record=get('configmap','release-record')['data']
pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
identities={status['imageID'] for pod in pods for status in pod['status']['containerStatuses'] if status['name']=='probe'}
assert record['runtimeImageID'] in identities, 'Bind the record to the running image identity'
assert record['imageDigest']==record['runtimeImageID'].split('@')[-1], 'Record the digest part of the image identity'
assert record['sbomFormat']=='CycloneDX', 'Name the SBOM format'
assert record['scope']=='alpine-installed-packages', 'Do not overstate inventory scope'
actual=kubectl('-n','starfleet','exec',pods[0]['metadata']['name'],'--','apk','info','-v').splitlines()
assert actual and json.loads(record['packages'])==sorted(actual), 'Record actual installed package evidence'
secret=get('secret','registry-credentials')
config=json.loads(base64.b64decode(secret['data']['.dockerconfigjson']))
entry=config['auths']['registry.example.test']
assert entry['username']=='builder' and entry['password']=='s3cret-pull-token', 'Store the given registry credential'
assert base64.b64decode(entry['auth']).decode()=='builder:s3cret-pull-token', 'The auth field must encode user:password'
account=get('serviceaccount','probe-runner')
assert [item['name'] for item in account.get('imagePullSecrets',[])]==['registry-credentials'], 'Attach the secret to the service account'
pod=get('pod','release-runner')
assert [item['name'] for item in pod['spec'].get('imagePullSecrets',[])]==['registry-credentials'], 'The pod must receive the pull secret through its service account'
