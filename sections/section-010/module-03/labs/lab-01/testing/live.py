shuttle_image_id = get('pod', 'shuttle')['status']['containerStatuses'][0]['imageID']
assert '@sha256:' in shuttle_image_id, 'The node must report a repository digest for the shuttle pod'
digest = shuttle_image_id.split('@sha256:')[-1]
if wants('pinned-reference'):
    image = get('pod', 'pinned-runner')['spec']['containers'][0]['image']
    assert image.endswith('@sha256:' + digest), 'Pin the image of pinned-runner to the digest the node reports for busybox'
    assert ':1.37.0' not in image, 'Use the digest alone as the identity, without the tag'
if wants('pinned-running'):
    statuses = get('pod', 'pinned-runner')['status'].get('containerStatuses', [])
    assert statuses and statuses[0].get('imageID', '').endswith(digest), 'The running pinned-runner container must use the pinned content'
