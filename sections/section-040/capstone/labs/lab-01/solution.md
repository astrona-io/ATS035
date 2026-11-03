---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Release A Workload Through Analysis, A Scan Gate And Restricted Admission Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-040)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-040" || exit 1
node_name="astro-ats-035-capstone-040-control-plane"
worker_name="astro-ats-035-capstone-040-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. Namespace `bay` holds three ConfigMaps: `analysis-source` with a workload document `workload.json` that is not deployed, `scan-results` with a scan report in Trivy JSON shape, and `scan-exceptions` with an ignore list. Namespace `bay` has no Pod Security Admission labels. Nothing is recorded or enforced yet.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

In namespace `bay`: (1) Label the namespace with `pod-security.kubernetes.io/enforce=restricted`, `pod-security.kubernetes.io/enforce-version=v1.35`, `pod-security.kubernetes.io/warn=restricted` and `pod-security.kubernetes.io/audit=restricted`. (2) Analyse `workload.json` without deploying it and record ConfigMap `analysis-findings` with the keys `privileged` (`true`), `runAsNonRoot` (`missing`), `allowPrivilegeEscalation` (`missing`) and `imageTag` (the tag the image uses). (3) Create ConfigMap `scan-gate` from `scan-results` and `scan-exceptions`: findings with severity HIGH or CRITICAL count, findings without a fixed version are ignored, findings on the ignore list are waived. Use the keys `decision` (`fail` when any blocking finding remains, otherwise `pass`), `blocking`, `waived` and `unfixed` (sorted, comma-separated identifiers without spaces), `severity` set to `HIGH,CRITICAL` and `ignoreUnfixed` set to `true`. (4) Create pod `corrected-reader` with the image `docker.io/library/busybox:1.37.0`, the command `sh -c "sleep 3600"`, `runAsNonRoot: true`, `runAsUser: 1000`, `runAsGroup: 1000`, the `RuntimeDefault` seccomp profile, `allowPrivilegeEscalation: false` and all capabilities dropped. It must be Ready. The original unsafe document must be rejected by the namespace, and you must not deploy it. Keep the three source ConfigMaps unchanged.

Save this as `pod-corrected-reader.yaml`. The namespace carries the Pod Security Admission labels, and the pod meets the `restricted` standard:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bay
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.35
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
---
apiVersion: v1
kind: Pod
metadata:
  name: corrected-reader
  namespace: bay
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
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
```

Apply it:

```sh
kubectl apply -f pod-corrected-reader.yaml
```

Save this as `compute-records.py`. It reads the three source ConfigMaps, derives the findings and the gate decision, and applies the two result ConfigMaps. The script is the analysis and the gate rules in code, so read it before you run it:

```python
import json
import subprocess
import tempfile
from pathlib import Path

CONTEXT = "kind-astro-ats-035-capstone-040"


def run(*args):
    result = subprocess.run(args, check=True, text=True, capture_output=True, timeout=30)
    return result.stdout.strip()


assert run('kubectl', 'config', 'current-context') == CONTEXT, 'Select the private environment'
CONFIG = {name: json.loads(run('kubectl', '-n', 'bay', 'get', 'configmap', name, '-o', 'json'))['data'] for name in ('analysis-source', 'scan-results', 'scan-exceptions')}
workload = json.loads(CONFIG['analysis-source']['workload.json'])
container = workload['spec']['containers'][0]
security = container.get('securityContext', {})
image_name = container['image'].rsplit('/', 1)[-1]
FINDINGS = {
    'privileged': str(security.get('privileged', False)).lower(),
    'runAsNonRoot': 'missing' if 'runAsNonRoot' not in workload['spec'].get('securityContext', {}) else 'present',
    'allowPrivilegeEscalation': 'missing' if 'allowPrivilegeEscalation' not in security else 'present',
    'imageTag': image_name.split(':', 1)[1] if ':' in image_name else 'latest',
}
results = json.loads(CONFIG['scan-results']['results.json'])
ignored = {line.strip() for line in CONFIG['scan-exceptions']['trivyignore.txt'].splitlines() if line.strip() and not line.startswith('#')}
blocking, waived, unfixed = [], [], []
for target in results['Results']:
    for finding in target.get('Vulnerabilities', []):
        if finding['Severity'] not in ('HIGH', 'CRITICAL'):
            continue
        identifier = finding['VulnerabilityID']
        if not finding.get('FixedVersion'):
            unfixed.append(identifier)
        elif identifier in ignored:
            waived.append(identifier)
        else:
            blocking.append(identifier)
GATE = {'decision': 'fail' if blocking else 'pass', 'blocking': ','.join(sorted(blocking)), 'waived': ','.join(sorted(waived)),
        'unfixed': ','.join(sorted(unfixed)), 'severity': 'HIGH,CRITICAL', 'ignoreUnfixed': 'true'}

with tempfile.TemporaryDirectory(prefix='training-report-') as temporary:
    for config_name, values in (('analysis-findings', FINDINGS), ('scan-gate', GATE)):
        source = Path(temporary) / (config_name + '.json')
        source.write_text(json.dumps({'apiVersion': 'v1', 'kind': 'ConfigMap', 'metadata': {'name': config_name, 'namespace': 'bay'}, 'data': values}))
        run('kubectl', 'apply', '-f', str(source))
```

Run it:

```sh
python3 compute-records.py
```

The unsafe document in `analysis-source` is not applied. To see that the namespace would reject it, extract it and run a server-side dry run:

```sh
kubectl -n bay get configmap analysis-source -o jsonpath='{.data.workload\.json}' > unsafe-source.json
kubectl -n bay apply --dry-run=server -f unsafe-source.json
```

The second command must fail with a message that contains `violates PodSecurity`.

## Verify The Result

Wait for the corrected pod and read the records:

```sh
kubectl -n bay wait --for=condition=Ready pod/corrected-reader --timeout=180s
kubectl -n bay get configmap analysis-findings scan-gate -o yaml
kubectl get namespace bay --show-labels
```

Analyse an unsafe workload document, decide a scan gate, enforce restricted admission and run the corrected workload. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required result. A matching field alone does not establish that a controller reconciled it.

After recording your result, remove the independent environment with `astrona destroy ats-035-capstone-040`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
