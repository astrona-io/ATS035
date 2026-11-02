---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Analyze And Correct A Workload Security Document Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-01-01" || exit 1
node_name="astro-ats-035-lab-040-01-01-control-plane"
worker_name="astro-ats-035-lab-040-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Analyze workload.json from ConfigMap analysis-source without deploying it. Record the privileged true and missing runAsNonRoot and allowPrivilegeEscalation findings in analysis-findings. Create analyzed-reader with the supplied non-root, no-privilege-escalation, dropped-capability, RuntimeDefault and read-only-root settings. It must be Ready. This focused field analysis is not a full image vulnerability scan or a replacement for a named scanner.

Save this as `configmap-analysis-findings.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: analysis-findings
  namespace: starfleet
data:
  privileged: 'true'
  runAsNonRoot: missing
  allowPrivilegeEscalation: missing
---
apiVersion: v1
kind: Pod
metadata:
  name: analyzed-reader
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  volumes:
  - name: scratch
    emptyDir: {}
```

Save this as `analyze-workload.py`:

```python
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

```

Apply the scoped correction:

```sh
python3 analyze-workload.py
kubectl apply -f configmap-analysis-findings.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/analyzed-reader --timeout=180s
```

Inspect a non-executed unsafe resource definition and run a corrected restricted workload. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-035-lab-040-01-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
