source=json.loads(get('configmap','analysis-source')['data']['workload.json'])
assert source['spec']['containers'][0]['securityContext']['privileged'] is True, 'Preserve the static input evidence'
