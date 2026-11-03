---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Record A Release With Inventory, Digest And Pull Access Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-020)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-020" || exit 1
node_name="astro-ats-035-capstone-020-control-plane"
worker_name="astro-ats-035-capstone-020-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods and a ServiceAccount named probe-runner. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create the ConfigMap release-record in starfleet with these keys. image: docker.io/library/python:3.13-alpine. runtimeImageID: the imageID of a ready probe container. imageDigest: the part of the imageID after the last at sign, or the whole value when it has no at sign. sbomFormat: CycloneDX. scope: alpine-installed-packages. packages: a JSON list of the sorted lines of apk info -v from a probe pod. Then create the Secret registry-credentials of type kubernetes.io/dockerconfigjson in starfleet for the registry registry.example.test with the user builder and the password s3cret-pull-token, add it to the imagePullSecrets of the existing ServiceAccount probe-runner, and run a pod named release-runner with that service account, the image docker.io/library/busybox:1.37.0 and the command sleep 3600. The pod must receive the pull secret through its service account. Preserve the original application. The record is evidence for one image; it is not a signature, a provenance attestation or a vulnerability scan.

Save this as `registry-pull-access.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: starfleet
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{"auths":{"registry.example.test":{"username":"builder","password":"s3cret-pull-token","auth":"YnVpbGRlcjpzM2NyZXQtcHVsbC10b2tlbg=="}}}'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: probe-runner
  namespace: starfleet
imagePullSecrets:
- name: registry-credentials
---
apiVersion: v1
kind: Pod
metadata:
  name: release-runner
  namespace: starfleet
spec:
  serviceAccountName: probe-runner
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f registry-pull-access.yaml
```

Save this as `record-release.py`:

```python
import json,subprocess,tempfile
from pathlib import Path
CONTEXT="kind-astro-ats-035-capstone-020"
def run(*args):
    result=subprocess.run(args,check=True,text=True,capture_output=True,timeout=30)
    return result.stdout.strip()
assert run('kubectl','config','current-context')==CONTEXT, 'Select the private environment'

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
```

Run it:

```sh
python3 record-release.py
```

## Verify The Result

Observe the actual result. Status convergence and matching fields establish different parts of the result, so check both.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/release-runner --timeout=180s
```

Then check the result:

```sh
kubectl -n starfleet get configmap release-record -o jsonpath='{.data.imageDigest}{"\n"}'
kubectl -n starfleet get pod release-runner -o jsonpath='{.spec.imagePullSecrets[*].name}{"\n"}'
```

Combine a package inventory, an image digest, an SBOM format and registry pull access into one release record. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-035-capstone-020`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
