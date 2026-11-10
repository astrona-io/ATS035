source=json.loads(get('configmap','analysis-source')['data']['workload.json'])
assert source['spec']['containers'][0]['securityContext']['privileged'] is True, 'Preserve the static input evidence'
# Kubernetes appends the service account token volume, so look the declared one up by name.
spec = get('pod', 'analyzed-reader')['spec']
mounts = [item for item in spec['containers'][0].get('volumeMounts', []) if item['name'] == 'scratch']
volumes = [item for item in spec.get('volumes', []) if item['name'] == 'scratch']
assert len(mounts) == 1 and contains(mounts[0], {'name': 'scratch', 'mountPath': '/scratch'}), 'Mount the scratch volume at /scratch as specified'
assert len(volumes) == 1 and contains(volumes[0], {'name': 'scratch', 'emptyDir': {}}), 'Declare the scratch volume as specified'
