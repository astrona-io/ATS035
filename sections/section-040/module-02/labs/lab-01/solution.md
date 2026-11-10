---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Decide A Scan Gate From Scan Results Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-02-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-02-01" || exit 1
node_name="astro-ats-035-lab-040-02-01-control-plane"
worker_name="astro-ats-035-lab-040-02-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The ConfigMap `scan-results` in `starfleet-035-040-02-01` holds a scan report in Trivy JSON shape, and the ConfigMap `scan-exceptions` holds an ignore list. No gate decision has been recorded.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet-035-040-02-01 get pods -o wide
kubectl get nodes -o wide
```

Read `results.json` from ConfigMap `scan-results` and the ignore list `trivyignore.txt` from ConfigMap `scan-exceptions` in `starfleet-035-040-02-01`. The gate looks only at findings with severity HIGH or CRITICAL and ignores findings that have no fixed version. A finding on the ignore list is waived. Create ConfigMap `scan-gate` in `starfleet-035-040-02-01` with these keys: `decision` (`fail` when any blocking finding remains, otherwise `pass`), `blocking`, `waived` and `unfixed` (each a sorted, comma-separated list of finding identifiers without spaces), `severity` set to `HIGH,CRITICAL` and `ignoreUnfixed` set to `true`. Do not change the report or the ignore list. The report is test data, and a gate decision is not proof that an image is safe.

Save this as `compute-scan-gate.py`. It reads the two ConfigMaps, applies the gate rules and prints the result. It does not change the cluster:

```python
import json
import os
import subprocess
import sys

CONTEXT = os.environ.get('ASTRONA_KUBE_CONTEXT') or 'kind-astro-ats-035-lab-040-02-01'


def run(*args):
    result = subprocess.run(args, check=True, text=True, capture_output=True, timeout=30)
    return result.stdout.strip()


if run('kubectl', 'config', 'current-context') != CONTEXT:
    sys.exit('Refusing to operate on another Kubernetes context')
CONFIG = {name: json.loads(run('kubectl', '-n', 'starfleet-035-040-02-01', 'get', 'configmap', name, '-o', 'json'))['data'] for name in ('scan-results', 'scan-exceptions')}
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
print(json.dumps(GATE, indent=2))
```

Run it and read the printed values:

```sh
python3 compute-scan-gate.py
```

Save this as `configmap-scan-gate.yaml`. The values are the ones the script prints:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scan-gate
  namespace: starfleet-035-040-02-01
data:
  decision: 'fail'
  blocking: 'FIXTURE-0001,FIXTURE-0002'
  waived: 'FIXTURE-0005'
  unfixed: 'FIXTURE-0003'
  severity: 'HIGH,CRITICAL'
  ignoreUnfixed: 'true'
```

Apply it:

```sh
kubectl apply -f configmap-scan-gate.yaml
```

## Verify The Result

Read the recorded decision back and compare it with the script output:

```sh
kubectl -n starfleet-035-040-02-01 get configmap scan-gate -o jsonpath='{.data}'
```

Compute a release gate decision from supplied Trivy-style scan results and record it. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required result. A matching field alone does not establish that a controller reconciled it.

After recording your result, remove the independent environment with `astrona destroy ats-035-lab-040-02-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
