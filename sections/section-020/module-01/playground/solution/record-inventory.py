import json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or 'kind-astro-ats-035-playground-020-01'
CLUSTER = os.environ.get('ASTRONA_KIND_CLUSTER') or 'astro-ats-035-playground-020-01'
ENGINE = os.environ.get('ASTRONA_CONTAINER_ENGINE') or ('podman' if shutil.which('podman') else 'docker')
NODE = CLUSTER + '-control-plane'
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
if run('kubectl', 'config', 'current-context') != CONTEXT:
    sys.exit('Refusing to operate on another Kubernetes context')
if run(ENGINE, 'inspect', NODE, '--format', '{{index .Config.Labels "io.x-k8s.kind.cluster"}}') != CLUSTER:
    sys.exit('Refusing an unrelated node container')

pods=json.loads(run('kubectl','-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
pod=pods[0]
packages=run('kubectl','-n','starfleet','exec',pod['metadata']['name'],'--','apk','info','-v').splitlines()
assert packages
identity=next(status['imageID'] for status in pod['status']['containerStatuses'] if status['name']=='probe')
report_name='supply-inventory';report={'image':'docker.io/library/python:3.13-alpine','runtimeImageID':identity,'packages':json.dumps(sorted(packages)),'scope':'alpine-installed-packages'}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet'},'data':report}))
    run('kubectl','apply','-f',str(source))

