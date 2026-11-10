import json,os,subprocess,sys,tempfile
from pathlib import Path
CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or 'kind-astro-ats-035-playground-020-02'
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
if run('kubectl', 'config', 'current-context') != CONTEXT:
    sys.exit('Refusing to operate on another Kubernetes context')

pods=json.loads(run('kubectl','-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
pod=pods[0]
lines=run('kubectl','-n','starfleet','exec',pod['metadata']['name'],'--','apk','info','-v').splitlines()
assert lines
identity=next(status['imageID'] for status in pod['status']['containerStatuses'] if status['name']=='probe')
components=[]
for line in sorted(lines):
    name,version,release=line.rsplit('-',2)
    full=version+'-'+release
    components.append({'type':'library','name':name,'version':full,'purl':'pkg:apk/alpine/'+name+'@'+full})
bom={'bomFormat':'CycloneDX','specVersion':'1.5','version':1,'metadata':{'component':{'type':'container','name':'docker.io/library/python','version':identity}},'components':components}
data={'format':'CycloneDX','specVersion':'1.5','subject':identity,'scope':'alpine-installed-packages','componentCount':str(len(components)),'bom':json.dumps(bom,sort_keys=True)}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':'sbom-record','namespace':'starfleet'},'data':data}))
    run('kubectl','apply','-f',str(source))
