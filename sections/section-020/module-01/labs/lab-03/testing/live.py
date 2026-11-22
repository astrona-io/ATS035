# Run by testing/check.py, which provides wants(), get(), command(), kubectl() and NAMESPACE.
SYFT_IMAGE = 'docker.io/anchore/syft:v1.57.0'


def ready_probe_pods():
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
    ready = []
    for pod in pods:
        if pod['metadata'].get('deletionTimestamp'):
            continue
        for status in pod['status'].get('containerStatuses', []):
            if status.get('name') == 'probe' and status.get('ready') and status.get('imageID'):
                ready.append((pod['metadata']['name'], status['imageID']))
    assert ready, 'No ready probe container'
    return ready


def installed_packages(pod):
    """Every name@version in the Alpine package database of a running probe pod."""
    database = command(['kubectl', '-n', NAMESPACE, 'exec', pod, '-c', 'probe', '--', 'cat', '/lib/apk/db/installed']).stdout
    packages, name = set(), None
    for line in database.splitlines():
        if line.startswith('P:'):
            name = line[2:]
        elif line.startswith('V:') and name:
            packages.add(name + '@' + line[2:])
            name = None
    assert packages, pod + ' has no Alpine package database'
    return packages


def sbom_record():
    return get('configmap', 'probe-sbom').get('data', {})


if wants('scan-job'):
    job = get('job', 'sbom-probe')
    template = job['spec']['template']['spec']
    assert any(container.get('image') == SYFT_IMAGE for container in template.get('containers', [])), 'A container of sbom-probe must run ' + SYFT_IMAGE
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'job-name=sbom-probe', '-o', 'json'))['items']
    finished = [pod for pod in pods if pod['status'].get('phase') == 'Succeeded']
    assert finished, 'No succeeded sbom-probe pod'
    running = {image for _, image in ready_probe_pods()}
    copied = {status.get('imageID') for pod in finished for status in pod['status'].get('initContainerStatuses', [])}
    assert copied & running, 'An init container of sbom-probe must run the image ID of the probe pods: ' + ', '.join(sorted(running))

if wants('sbom-packages'):
    try:
        document = json.loads(sbom_record().get('sbom.cdx.json', ''))
    except ValueError:
        assert False, 'The sbom.cdx.json key of probe-sbom must hold the JSON from Syft'
    assert document.get('bomFormat') == 'CycloneDX', 'The SBOM must be a CycloneDX document'
    tools = document.get('metadata', {}).get('tools', {})
    tools = tools.get('components', []) if isinstance(tools, dict) else tools
    assert any(tool.get('name') == 'syft' and tool.get('version') == '1.57.0' for tool in tools), 'The SBOM must be made by Syft 1.57.0'
    listed = {item.get('name', '') + '@' + item.get('version', '') for item in document.get('components', [])
              if str(item.get('purl', '')).startswith('pkg:apk/')}
    pod = ready_probe_pods()[0][0]
    installed = installed_packages(pod)
    missing, extra = sorted(installed - listed), sorted(listed - installed)
    assert not missing and not extra, 'The SBOM does not match the packages of ' + pod + '; missing: ' + ', '.join(missing[:5]) + '; extra: ' + ', '.join(extra[:5])

if wants('sbom-subject'):
    recorded = sbom_record().get('runtimeImageID', '').strip()
    running = {image for _, image in ready_probe_pods()}
    assert recorded, 'Set the runtimeImageID key of probe-sbom'
    assert recorded in running, 'runtimeImageID must be the imageID of a ready probe container: ' + ', '.join(sorted(running))
