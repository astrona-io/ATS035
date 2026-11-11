#!/usr/bin/env bash
set -euo pipefail
context="${ASTRONA_KUBE_CONTEXT:-kind-astro-ats-035-playground-020-02}"
if [[ "$(kubectl config current-context)" != "$context" ]]; then
  printf 'Refusing to operate on another Kubernetes context\n' >&2
  exit 1
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(
cd "$work"
pod=$(kubectl -n starfleet get pods -l app=probe -o jsonpath='{.items[0].metadata.name}')
kubectl -n starfleet wait --for=condition=Ready "pod/$pod" --timeout=120s
kubectl -n starfleet get "pod/$pod" -o jsonpath='{.status.containerStatuses[?(@.name=="probe")].imageID}' > image-id.txt
kubectl -n starfleet exec "$pod" -- apk info -v | sort > packages.txt
python3 - <<'PYTHON'
import json
from pathlib import Path
components = []
for line in Path('packages.txt').read_text().splitlines():
    name, version, release = line.rsplit('-', 2)
    version = version + '-' + release
    components.append({'type': 'library', 'name': name, 'version': version,
                       'purl': f'pkg:apk/alpine/{name}@{version}'})
bom = {'bomFormat': 'CycloneDX', 'specVersion': '1.5', 'components': components}
Path('bom.json').write_text(json.dumps(bom, indent=2) + '\n')
print('componentCount=' + str(len(components)))
PYTHON
python3 - <<'PYTHON'
import json
from pathlib import Path
bom = json.loads(Path('bom.json').read_text())
packages = Path('packages.txt').read_text().splitlines()
assert len(bom['components']) == len(packages) > 5
assert {c['name'] + '-' + c['version'] for c in bom['components']} == set(packages)
assert 'sha256:' in Path('image-id.txt').read_text()
print('PASS: lesson builds a complete Alpine inventory tied to the running image')
PYTHON
)
lab_directory="$(cd "$(dirname "$0")/.." && pwd)"
if bash "$lab_directory/validate.sh"; then
  printf 'Starting state unexpectedly passes grading\n' >&2
  exit 1
fi
bash "$lab_directory/solution/apply.sh"
for attempt in $(seq 1 20); do
  if bash "$lab_directory/validate.sh"; then exit 0; fi
  sleep 3
done
printf 'Reference result did not pass within the bounded retry period\n' >&2
exit 1
