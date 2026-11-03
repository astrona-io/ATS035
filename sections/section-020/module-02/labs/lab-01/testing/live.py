record=get('configmap','sbom-record')['data']
pods=json.loads(kubectl('-n','starfleet','get','pods','-l','app=probe','-o','json'))['items']
identities={status['imageID'] for pod in pods for status in pod['status']['containerStatuses'] if status['name']=='probe'}
assert record['subject'] in identities, 'Bind the record to the running image identity'
assert record['format']=='CycloneDX' and record['specVersion']=='1.5', 'Declare the document format and version'
assert record['scope']=='alpine-installed-packages', 'Do not overstate inventory scope'
bom=json.loads(record['bom'])
assert bom['bomFormat']=='CycloneDX' and bom['specVersion']=='1.5', 'The document must declare its own format'
actual=kubectl('-n','starfleet','exec',pods[0]['metadata']['name'],'--','apk','info','-v').splitlines()
assert actual, 'Collect package evidence'
expected=[]
for line in actual:
    name,version,release=line.rsplit('-',2)
    full=version+'-'+release
    expected.append((name,full,'pkg:apk/alpine/'+name+'@'+full))
found=[(item['name'],item['version'],item['purl']) for item in bom['components']]
assert sorted(found)==sorted(expected), 'Components must match the installed packages with package URLs'
assert record['componentCount']==str(len(expected)), 'Record the component count'
