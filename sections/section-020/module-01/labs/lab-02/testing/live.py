# Compare image-inventory with the container statuses of the pods that run now.
pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-o', 'json'))['items']
assert len(pods) >= 3, 'The probe pods and the shuttle pod must keep running'
live_init = set()
live_app = set()
for pod in pods:
    name = pod['metadata']['name']
    for status in pod.get('status', {}).get('initContainerStatuses', []):
        live_init.add((name, status['name'], status['image'], status['imageID']))
    for status in pod.get('status', {}).get('containerStatuses', []):
        live_app.add((name, status['name'], status['image'], status['imageID']))
assert live_init and live_app, 'The pods must report container statuses'
record = get('configmap', 'image-inventory').get('data', {})
lines = [line.split() for line in record.get('containers', '').splitlines() if line.strip()]
assert lines, 'Store one line per container under the key containers'
assert all(len(fields) == 4 for fields in lines), 'Each line needs four fields: pod, container, image and imageID'
listed = {tuple(fields[:3]) for fields in lines}
if wants('inventory-containers'):
    missing = {entry[:3] for entry in live_app} - listed
    assert not missing, 'Add a line with pod, container and image for every running app container'
if wants('inventory-init-containers'):
    missing = {entry[:3] for entry in live_init} - listed
    assert not missing, 'Add a line with pod, container and image for every init container'
if wants('inventory-image-ids'):
    recorded = [tuple(fields) for fields in lines]
    assert len(recorded) == len(set(recorded)), 'List each container only once'
    assert set(recorded) == live_init | live_app, 'Every line must carry the imageID from the live pod status, with no extra lines'
