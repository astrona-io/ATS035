pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
assert pods, 'The probe pods must keep running'
if wants('sbom-metadata'):
    record = get('configmap', 'sbom-record').get('data', {})
    identities = {status['imageID'] for pod in pods for status in pod['status'].get('containerStatuses', []) if status['name'] == 'probe'}
    assert record.get('subject') in identities, 'Set subject to the imageID of a ready probe container'
    assert record.get('scope') == 'alpine-installed-packages', 'Set scope to alpine-installed-packages'
if wants('sbom-components'):
    record = get('configmap', 'sbom-record').get('data', {})
    try:
        bom = json.loads(record.get('bom', ''))
    except ValueError:
        bom = None
    assert isinstance(bom, dict), 'Store a JSON CycloneDX document under the key bom'
    assert bom.get('bomFormat') == 'CycloneDX' and bom.get('specVersion') == '1.5', 'The bom document must declare bomFormat CycloneDX and specVersion 1.5'
    actual = kubectl('-n', NAMESPACE, 'exec', pods[0]['metadata']['name'], '--', 'apk', 'info', '-v').splitlines()
    assert actual, 'Collect package evidence'
    expected = []
    for line in actual:
        name, version, release = line.rsplit('-', 2)
        full = version + '-' + release
        expected.append((name, full, 'pkg:apk/alpine/' + name + '@' + full))
    found = [(item.get('name'), item.get('version'), item.get('purl')) for item in bom.get('components', [])]
    assert sorted(found) == sorted(expected), 'Components must match the installed packages with package URLs'
    assert record.get('componentCount') == str(len(expected)), 'Set componentCount to the number of installed packages'
