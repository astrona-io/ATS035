address=get('pod','minimal-server')['status']['podIP']
assert 'minimal-version=v1' in kubectl('-n','starfleet','exec','shuttle','--','wget','-q','-T','3','-O-','http://'+address+':8080/'), 'Serve the content with the selected process'
assert kubectl('-n','starfleet','exec','minimal-server','--','sh','-c','test ! -x /usr/local/bin/python && test ! -x /usr/bin/python && printf absent')=='absent', 'Do not add the unused language runtime'
