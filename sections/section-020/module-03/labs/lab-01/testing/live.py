import base64, time, uuid
info=get('configmap','registry-info')['data']
if wants('pull-secret'):
    secret=get('secret','registry-credentials')
    try:
        credential=json.loads(base64.b64decode(secret['data']['.dockerconfigjson']))['auths'][info['server']]
        pair=base64.b64decode(credential['auth']).decode()
    except (KeyError, ValueError, TypeError): pair=''
    assert pair=='builder:training-password', 'Provide the live registry credential for its exact server address'
if wants('release-check'):
    existing=get('pod','release-check')
    assert existing['spec']['serviceAccountName']=='probe-runner', 'Use probe-runner'
    container=existing['spec']['containers'][0]
    assert container['image']==info['image'] and container['imagePullPolicy']=='Always', 'Pull the private image with Always'
    assert existing['status'].get('phase')=='Running', 'Run release-check after repairing its credentials'
    name='pull-proof-'+uuid.uuid4().hex[:8]
    probe={'apiVersion':'v1','kind':'Pod','metadata':{'name':name,'namespace':NAMESPACE},'spec':{'serviceAccountName':'probe-runner','restartPolicy':'Never','containers':[{'name':'client','image':info['image'],'imagePullPolicy':'Always','command':['sh','-c','echo authenticated-pull']}]}}
    # Omit imagePullSecrets: admission must copy the ServiceAccount setting.
    created=subprocess.run(['kubectl','create','-f','-'],input=json.dumps(probe),text=True,capture_output=True,timeout=30)
    if created.returncode: raise RuntimeError(created.stderr)
    try:
        deadline=time.monotonic()+90
        while time.monotonic()<deadline:
            pod=get('pod',name)
            if pod['status'].get('phase') in ('Succeeded','Failed'): break
            time.sleep(2)
        assert pod['status'].get('phase')=='Succeeded', 'A fresh Pod must authenticate and pull the private image'
        assert kubectl('-n',NAMESPACE,'logs',name)=='authenticated-pull', 'Run the pulled image'
        assert pod['spec'].get('imagePullSecrets')==[{'name':'registry-credentials'}], 'Inherit the credential from probe-runner'
    finally:
        command(['kubectl','-n',NAMESPACE,'delete','pod',name,'--wait=false'])
