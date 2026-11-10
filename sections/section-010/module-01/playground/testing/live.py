address=get('pod','minimal-server')['status']['podIP']
assert 'minimal-version=v1' in kubectl('-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+':8080/'), 'Serve the content with the selected process'
assert kubectl('-n','starfleet','exec','minimal-server','--','sh','-c','test ! -x /usr/local/bin/python && test ! -x /usr/bin/python && printf absent')=='absent', 'Do not add the unused language runtime'
# Kubernetes appends the service account token volume, so look the declared one up by name.
spec = get('pod', 'minimal-server')['spec']
mounts = [item for item in spec['containers'][0].get('volumeMounts', []) if item['name'] == 'site']
volumes = [item for item in spec.get('volumes', []) if item['name'] == 'site']
assert len(mounts) == 1 and contains(mounts[0], {'name': 'site', 'mountPath': '/site', 'readOnly': True}), 'Mount the site volume at /site as specified'
assert len(volumes) == 1 and contains(volumes[0], {'name': 'site', 'configMap': {'name': 'minimal-content'}}), 'Declare the site volume as specified'
