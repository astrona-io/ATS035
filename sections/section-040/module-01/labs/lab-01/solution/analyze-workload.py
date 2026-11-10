import json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or 'kind-astro-ats-035-lab-040-01-01'
CLUSTER = os.environ.get('ASTRONA_KIND_CLUSTER') or 'astro-ats-035-lab-040-01-01'
ENGINE = os.environ.get('ASTRONA_CONTAINER_ENGINE') or ('podman' if shutil.which('podman') else 'docker')
NODE = CLUSTER + '-control-plane'
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
if run('kubectl', 'config', 'current-context') != CONTEXT:
    sys.exit('Refusing to operate on another Kubernetes context')
if run(ENGINE, 'inspect', NODE, '--format', '{{index .Config.Labels "io.x-k8s.kind.cluster"}}') != CLUSTER:
    sys.exit('Refusing an unrelated node container')

workload=json.loads(json.loads(run('kubectl','-n','starfleet-035-040-01-01','get','configmap','analysis-source','-o','json'))['data']['workload.json'])
container=workload['spec']['containers'][0];security=container.get('securityContext',{})
report_name='analysis-findings';report={'privileged':str(security.get('privileged',False)).lower(),'runAsNonRoot':'missing' if 'runAsNonRoot' not in workload['spec'].get('securityContext',{}) else 'present','allowPrivilegeEscalation':'missing' if 'allowPrivilegeEscalation' not in security else 'present'}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet-035-040-01-01'},'data':report}))
    run('kubectl','apply','-f',str(source))

