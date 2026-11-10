source = json.loads(get('configmap', 'analysis-source')['data']['workload.json'])
assert source['spec']['containers'][0]['securityContext']['privileged'] is True, 'Preserve the static input evidence in analysis-source'
if wants('analyzed-reader'):
    # Kubernetes appends the service account token volume, so look the declared one up by name.
    spec = get('pod', 'analyzed-reader')['spec']
    mounts = [item for item in spec['containers'][0].get('volumeMounts', []) if item['name'] == 'scratch']
    volumes = [item for item in spec.get('volumes', []) if item['name'] == 'scratch']
    assert len(mounts) == 1 and all(mounts[0].get(key) == value for key, value in {'name': 'scratch', 'mountPath': '/scratch'}.items()), 'Mount the scratch volume at /scratch as specified'
    assert len(volumes) == 1 and all(volumes[0].get(key) == value for key, value in {'name': 'scratch', 'emptyDir': {}}.items()), 'Declare the scratch volume as specified'
