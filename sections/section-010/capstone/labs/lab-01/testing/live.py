shuttle_image_id = get('pod', 'shuttle')['status']['containerStatuses'][0]['imageID']
assert '@sha256:' in shuttle_image_id, 'The node must report a repository digest for the shuttle pod'
digest = shuttle_image_id.split('@sha256:')[-1]
deployment = get('deployment', 'minimal-web')
assert deployment['spec']['template']['spec']['containers'][0]['image'].endswith('@sha256:' + digest), 'Pin the image to the digest the node reports for busybox'
body = kubectl('-n', 'starfleet', 'exec', 'shuttle', '--', 'wget', '-q', '-T', '3', '-O-', 'http://minimal-web.starfleet.svc.cluster.local/')
assert 'capstone-version=v1' in body, 'The Service must return the page from the hardened pod'
pods = json.loads(kubectl('-n', 'starfleet', 'get', 'pods', '-l', 'app=minimal-web', '-o', 'json'))['items']
assert pods, 'The Deployment must have a running pod'
user = kubectl('-n', 'starfleet', 'exec', pods[0]['metadata']['name'], '--', 'id', '-u')
assert user == '10001', 'The process must run as the numeric user 10001'
