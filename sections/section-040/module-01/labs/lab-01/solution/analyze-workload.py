import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-035-lab-040-01-01"
NODE="astro-ats-035-lab-040-01-01-control-plane"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'
assert run('podman','inspect',NODE,'--format','{{index .Config.Labels "io.x-k8s.kind.cluster"}}')=='astro-ats-035-lab-040-01-01', 'Refusing an unrelated node container'

workload=json.loads(json.loads(run('kubectl','-n','starfleet','get','configmap','analysis-source','-o','json'))['data']['workload.json'])
container=workload['spec']['containers'][0];security=container.get('securityContext',{})
report_name='analysis-findings';report={'privileged':str(security.get('privileged',False)).lower(),'runAsNonRoot':'missing' if 'runAsNonRoot' not in workload['spec'].get('securityContext',{}) else 'present','allowPrivilegeEscalation':'missing' if 'allowPrivilegeEscalation' not in security else 'present'}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    source=Path(temporary)/'configmap-report.json'
    source.write_text(json.dumps({'apiVersion':'v1','kind':'ConfigMap','metadata':{'name':report_name,'namespace':'starfleet'},'data':report}))
    run('kubectl','apply','-f',str(source))

