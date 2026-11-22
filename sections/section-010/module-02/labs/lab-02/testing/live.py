def probe_fact(script):
    """Read one fact from a running probe pod, the same way the task does."""
    result = command(['kubectl', '-n', NAMESPACE, 'exec', 'deploy/probe', '--', 'sh', '-c', script])
    value = result.stdout.strip()
    assert value, 'The probe pod returned no value for: ' + script
    return value


def report_value(key):
    data = get('configmap', 'base-image-report').get('data') or {}
    assert key in data, 'ConfigMap base-image-report needs the key ' + key
    return data[key].strip()


def beacon_pods():
    """Ready beacon pods that run the BusyBox image and are not being deleted."""
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=beacon', '-o', 'json'))['items']
    current = [pod for pod in pods
               if not pod['metadata'].get('deletionTimestamp')
               and pod['spec']['containers'][0]['image'] == 'docker.io/library/busybox:1.37.0'
               and any(condition['type'] == 'Ready' and condition['status'] == 'True'
                       for condition in pod.get('status', {}).get('conditions', []))]
    assert current, 'No ready beacon pod runs docker.io/library/busybox:1.37.0'
    return current


if wants('loader-recorded'):
    assert report_value('probeLoader') == probe_fact('ls /lib/ld-musl*'), 'probeLoader must be the musl loader path listed in a running probe pod'

if wants('package-count-recorded'):
    assert report_value('probePackages') == probe_fact('apk info | wc -l'), 'probePackages must be the apk package count read in a running probe pod'

if wants('beacon-on-busybox'):
    for pod in beacon_pods():
        name = pod['metadata']['name']
        lookup = command(['kubectl', '-n', NAMESPACE, 'exec', name, '--', 'sh', '-c', 'which apk || which python'], success=False)
        assert lookup.returncode == 1 and not lookup.stdout.strip(), 'The beacon container must have no apk and no python'

if wants('beacon-still-works'):
    for pod in beacon_pods():
        logs = kubectl('-n', NAMESPACE, 'logs', pod['metadata']['name'])
        assert 'version=v1' in logs, 'The beacon pod on BusyBox must still print the probe response'
