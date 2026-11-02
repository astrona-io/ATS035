report=get('configmap','supply-inventory')['data']
pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
assert report['runtimeImageID'] in {status['imageID'] for pod in pods for status in pod['status']['containerStatuses'] if status['name']=='probe'}, 'Bind inventory to running contents'
actual=kubectl('-n','starfleet','exec',pods[0]['metadata']['name'],'--','apk','info','-v').splitlines()
assert json.loads(report['packages'])==sorted(actual) and actual, 'Record actual installed package evidence'
assert report['scope']=='alpine-installed-packages', 'Do not overstate inventory scope'
