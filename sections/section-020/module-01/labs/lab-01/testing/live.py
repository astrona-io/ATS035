pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
assert pods, 'The probe pods must keep running'
if wants('inventory-subject'):
    report = get('configmap', 'supply-inventory').get('data', {})
    identities = {status['imageID'] for pod in pods for status in pod['status'].get('containerStatuses', []) if status['name'] == 'probe'}
    assert report.get('runtimeImageID') in identities, 'Set runtimeImageID to the imageID of a ready probe container'
    assert report.get('scope') == 'alpine-installed-packages', 'Set scope to alpine-installed-packages'
if wants('inventory-packages'):
    report = get('configmap', 'supply-inventory').get('data', {})
    actual = kubectl('-n', NAMESPACE, 'exec', pods[0]['metadata']['name'], '--', 'apk', 'info', '-v').splitlines()
    try:
        listed = json.loads(report.get('packages', ''))
    except ValueError:
        listed = None
    assert actual and listed == sorted(actual), 'Record the sorted apk info -v lines as a JSON list in packages'
