FIXED_IMAGE = 'docker.io/library/busybox:1.37.0'


def scout_containers():
    """(requested image, imageID) of every running, ready scout container that is not being deleted."""
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=scout', '-o', 'json'))['items']
    found = []
    for pod in pods:
        if pod['metadata'].get('deletionTimestamp') or pod['status'].get('phase') != 'Running':
            continue
        requested = {container['name']: container['image'] for container in pod['spec']['containers']}
        for status in pod['status'].get('containerStatuses', []):
            if status['name'] == 'client' and status.get('ready') and status.get('imageID'):
                found.append((requested['client'], status['imageID']))
    return found


if wants('deployment-repaired'):
    running = scout_containers()
    assert running, 'A scout pod must be running and ready'
    assert all(image == FIXED_IMAGE for image, _ in running), 'Every running scout container must use ' + FIXED_IMAGE
if wants('identity-recorded'):
    evidence = get('configmap', 'pull-evidence').get('data', {})
    running = scout_containers()
    assert running, 'A scout pod must be running and ready before its identity can be recorded'
    assert evidence.get('requested') == FIXED_IMAGE, 'Set requested to the image that the running scout pod asks for'
    assert 'sha256:' in evidence.get('resolved', ''), 'Set resolved to the imageID from the pod status, which contains sha256:'
    assert (evidence.get('requested'), evidence.get('resolved')) in running, 'resolved must equal the imageID of a running scout container'
