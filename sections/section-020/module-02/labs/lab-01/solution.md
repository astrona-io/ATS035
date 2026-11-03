---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Record A Structured Package Inventory Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-02-01" || exit 1
node_name="astro-ats-035-lab-020-02-01-control-plane"
worker_name="astro-ats-035-lab-020-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create the ConfigMap sbom-record in starfleet with these keys. format: CycloneDX. specVersion: 1.5. subject: the imageID of a ready probe container. scope: alpine-installed-packages. componentCount: the number of installed packages as a string. bom: a JSON document with bomFormat CycloneDX, specVersion 1.5 and a components list with one entry per line of apk info -v from a probe pod. Each entry has type library, name, version and purl. Split a line such as musl-1.2.5-r10 at its last two dashes: the name is the part before them and the version is the last two parts joined by a dash. The purl is pkg:apk/alpine/ followed by the name, an at sign and the version. Preserve the original application. This is an operating-system package list in one SBOM format; it does not include language packages, a signature or a vulnerability scan.

Save this as `build-sbom-record.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-035-lab-020-02-01"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'

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
```

Run it:

```sh
python3 build-sbom-record.py
```

## Verify The Result

Observe the actual result. Status convergence and matching fields establish different parts of the result, so check both.

Then check the result:

```sh
kubectl -n starfleet get configmap sbom-record -o jsonpath='{.data.componentCount}{"\n"}'
```

Record a CycloneDX-style component list for the running probe image, bound to its image identity. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-035-lab-020-02-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
