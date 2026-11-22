if wants('relay-always-pulls'):
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=relay', '-o', 'json'))['items']
    current = [pod for pod in pods
               if not pod['metadata'].get('deletionTimestamp')
               and pod['spec']['containers'][0].get('imagePullPolicy') == 'Always'
               and any(condition['type'] == 'Ready' and condition['status'] == 'True'
                       for condition in pod.get('status', {}).get('conditions', []))]
    assert current, 'No ready relay pod runs with imagePullPolicy Always'
    for pod in current:
        name = pod['metadata']['name']
        events = json.loads(kubectl('-n', NAMESPACE, 'get', 'events', '--field-selector',
                                    'involvedObject.name=' + name + ',reason=Pulled', '-o', 'json'))['items']
        assert any('Successfully pulled' in event.get('message', '') for event in events), \
            'The events of relay pod ' + name + ' must show that the kubelet pulled the image from the registry'
