import json,os,subprocess,sys,tempfile
from pathlib import Path
CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or 'kind-astro-ats-035-capstone-020'
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
if run('kubectl', 'config', 'current-context') != CONTEXT:
    sys.exit('Refusing to operate on another Kubernetes context')

pods=json.loads(run('kubectl','-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
pod=pods[0]
packages=run('kubectl','-n','starfleet','exec',pod['metadata']['name'],'--','apk','info','-v').splitlines()
assert packages
identity=next(status['imageID'] for status in pod['status']['containerStatuses'] if status['name']=='probe')
digest=identity.split('@')[-1]
data={'image':'docker.io/library/python:3.13-alpine','runtimeImageID':identity,'imageDigest':digest,'sbomFormat':'CycloneDX','packages':json.dumps(sorted(packages)),'scope':'alpine-installed-packages'}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'release-record','namespace':'starfleet'},'data':data}))
    run('kubectl','apply','-f',str(source))
