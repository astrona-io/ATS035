# Run by testing/check.py, which provides wants(), get(), command(), kubectl() and NAMESPACE.
LIMIT = 64 * 1024 * 1024


def shuttle_digest():
    image_id = get('pod', 'shuttle')['status']['containerStatuses'][0].get('imageID', '')
    assert '@sha256:' in image_id, 'The shuttle pod reports no registry digest'
    return image_id.split('@sha256:', 1)[1]


def web_container(deployment):
    containers = [container for container in deployment['spec']['template']['spec']['containers'] if container['name'] == 'web']
    assert containers, 'The minimal-web Deployment needs a container named web'
    return containers[0]


def running_pods():
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=minimal-web', '-o', 'json'))['items']
    running = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp') and pod['status'].get('phase') == 'Running']
    assert running, 'No running minimal-web pod'
    return running


if wants('pinned-deployment'):
    deployment = get('deployment', 'minimal-web')
    status = deployment.get('status', {})
    assert deployment['spec'].get('replicas', 1) == 1, 'Run one replica of minimal-web'
    assert status.get('observedGeneration', 0) >= deployment['metadata']['generation'], 'The current minimal-web generation has not been observed'
    assert status.get('updatedReplicas', 0) == 1 and status.get('availableReplicas', 0) == 1, 'The minimal-web rollout is incomplete'
    assert deployment['spec']['template']['metadata'].get('labels', {}).get('app') == 'minimal-web', 'The pods need the label app: minimal-web'
    container = web_container(deployment)
    wanted = 'docker.io/library/busybox@sha256:' + shuttle_digest()
    assert container.get('image') == wanted, 'The web container must use ' + wanted
    assert container.get('imagePullPolicy') == 'IfNotPresent', 'Set imagePullPolicy: IfNotPresent'
    assert container.get('command') == ['httpd', '-f', '-p', '8080', '-h', '/site'], 'The web container must run httpd -f -p 8080 -h /site'
    assert any(port.get('name') == 'http' and port.get('containerPort') == 8080 for port in container.get('ports', [])), 'Name the container port 8080 http'
    volumes = {volume['name']: volume for volume in deployment['spec']['template']['spec'].get('volumes', [])}
    mounts = [mount for mount in container.get('volumeMounts', []) if mount.get('mountPath') == '/site']
    assert mounts and mounts[0].get('readOnly') is True, 'Mount the site read-only at /site'
    assert volumes.get(mounts[0]['name'], {}).get('configMap', {}).get('name') == 'minimal-site', 'The /site volume must be the minimal-site ConfigMap'

if wants('resource-budget'):
    resources = web_container(get('deployment', 'minimal-web')).get('resources', {})
    requests = resources.get('requests', {})
    assert requests.get('cpu') and requests.get('memory'), 'Set a CPU request and a memory request on the web container'
    assert resources.get('limits', {}).get('memory') == '64Mi', 'Set the memory limit of the web container to 64Mi'
    for pod in running_pods():
        name = pod['metadata']['name']
        limit = command(['kubectl', '-n', NAMESPACE, 'exec', name, '-c', 'web', '--', 'cat', '/sys/fs/cgroup/memory.max'], success=False)
        assert limit.stdout.strip() == str(LIMIT), name + ' does not run with a 64Mi memory limit in its cgroup'
