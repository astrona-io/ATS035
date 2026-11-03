shuttle_image_id = get('pod', 'shuttle')['status']['containerStatuses'][0]['imageID']
assert '@sha256:' in shuttle_image_id, 'The node must report a repository digest for the shuttle pod'
digest = shuttle_image_id.split('@sha256:')[-1]
pinned = get('pod', 'pinned-runner')
assert pinned['spec']['containers'][0]['image'].endswith('@sha256:' + digest), 'Pin the image to the digest the node reports for busybox'
assert ':1.37.0' not in pinned['spec']['containers'][0]['image'], 'Use the digest alone as the identity'
running_id = pinned['status']['containerStatuses'][0]['imageID']
assert running_id.endswith(digest), 'The running container must use the pinned content'
