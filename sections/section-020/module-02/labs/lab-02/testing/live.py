# Compare the SBOM record and the VEX statement with the image that runs now.
import datetime

pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=probe', '-o', 'json'))['items']
identities = {status['imageID'] for pod in pods for status in pod.get('status', {}).get('containerStatuses', [])
              if status['name'] == 'probe' and status.get('ready') and status.get('imageID')}
assert identities, 'The probe pods must keep running'
digests = {identity.rsplit('@', 1)[-1] for identity in identities}
if wants('sbom-subject'):
    record = get('configmap', 'sbom-record').get('data', {})
    assert record.get('format') == 'CycloneDX' and record.get('scope') == 'alpine-installed-packages', 'Keep format and scope of sbom-record'
    assert record.get('subject') in identities, 'Set subject to the imageID of a ready probe container, not the tag'
if wants('sbom-image-digest'):
    record = get('configmap', 'sbom-record').get('data', {})
    digest = record.get('imageDigest', '')
    assert digest.startswith('sha256:') and '@' not in digest, 'Set imageDigest to the sha256: value after the last @ of the imageID'
    assert digest in digests, 'imageDigest must come from the imageID of a ready probe container'
if wants('vex-statement'):
    statement = get('configmap', 'vex-statement').get('data', {})
    finding = get('configmap', 'scan-finding').get('data', {})
    assert statement.get('vulnerability') == finding.get('vulnerability'), 'Name the vulnerability from scan-finding'
    assert statement.get('product') in digests, 'Set product to the live image digest, not the tag'
    assert statement.get('status') == 'not_affected', 'Set status to not_affected'
    assert statement.get('justification') == 'vulnerable_code_not_in_execute_path', 'Set justification to vulnerable_code_not_in_execute_path'
    assert statement.get('author', '').strip(), 'Record who made the statement in author'
    try:
        datetime.date.fromisoformat(statement.get('reviewBy', ''))
    except ValueError:
        raise AssertionError('Set reviewBy to a date in the form YYYY-MM-DD')
