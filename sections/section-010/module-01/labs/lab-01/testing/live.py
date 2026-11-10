if wants('minimal-server'):
    absent = command(['kubectl', '-n', NAMESPACE, 'exec', 'minimal-server', '--', 'sh', '-c',
                      'test ! -x /usr/local/bin/python && test ! -x /usr/bin/python && printf absent'], success=False)
    assert absent.stdout.strip() == 'absent', 'Do not add the unused language runtime to minimal-server'
if wants('serves-page'):
    address = get('pod', 'minimal-server')['status'].get('podIP')
    assert address, 'Pod minimal-server has no IP address yet'
    page = command(['kubectl', '-n', NAMESPACE, 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-',
                    'http://' + address + ':8080/'], success=False)
    assert 'minimal-version=v1' in page.stdout, 'Serve index.html from minimal-server on port 8080'
if wants('minimal-server'):
    # Kubernetes appends the service account token volume, so look the declared one up by name.
    spec = get('pod', 'minimal-server')['spec']
    mounts = [item for item in spec['containers'][0].get('volumeMounts', []) if item['name'] == 'site']
    volumes = [item for item in spec.get('volumes', []) if item['name'] == 'site']
    assert len(mounts) == 1 and contains(mounts[0], {'name': 'site', 'mountPath': '/site', 'readOnly': True}), 'Mount the site volume at /site as specified'
    assert len(volumes) == 1 and contains(volumes[0], {'name': 'site', 'configMap': {'name': 'minimal-content'}}), 'Declare the site volume as specified'
