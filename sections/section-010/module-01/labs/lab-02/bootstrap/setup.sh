#!/usr/bin/env bash
set -euo pipefail
sudo cloud-init status --wait >/dev/null
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io curl python3
sudo systemctl enable --now docker
sudo docker pull gcc:15.2.0
sudo install -d -m 0777 /srv/build /opt/astrona-live
sudo tee /srv/build/server.c >/dev/null <<'SOURCE'
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <string.h>
int main(void) {
 int fd=socket(AF_INET,SOCK_STREAM,0), one=1;
 setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
 struct sockaddr_in addr={.sin_family=AF_INET,.sin_port=htons(8080),.sin_addr.s_addr=INADDR_ANY};
 if(bind(fd,(struct sockaddr*)&addr,sizeof(addr)) || listen(fd,16)) return 1;
 for(;;) { int client=accept(fd,0,0); if(client<0) continue;
  char request[2048]; read(client,request,sizeof(request));
  const char *reply="HTTP/1.1 200 OK\r\nContent-Length: 14\r\nConnection: close\r\n\r\nbuilt-service\n";
  write(client,reply,strlen(reply)); close(client);
 }
}
SOURCE
sudo cp /srv/build/server.c /opt/astrona-live/server.c
sudo tee /srv/build/Dockerfile >/dev/null <<'DOCKERFILE'
FROM gcc:15.2.0
WORKDIR /src
COPY server.c .
RUN gcc -static -Os -s -o /server server.c
ENTRYPOINT ["/server"]
DOCKERFILE
sudo chmod 0666 /srv/build/Dockerfile

sudo install -d /opt/astrona-live
sudo tee /opt/astrona-live/check.py >/dev/null <<'PY_CHECK'

import io,json,pathlib,re,subprocess,sys,tarfile,time,urllib.request,uuid
def run(args,timeout=60): return subprocess.run(args,text=True,capture_output=True,timeout=timeout)
def check(outcome):
    assert pathlib.Path('/srv/build/server.c').read_bytes()==pathlib.Path('/opt/astrona-live/server.c').read_bytes(), 'Preserve the supplied application source'
    recipe=pathlib.Path('/srv/build/Dockerfile').read_text()
    assert len(re.findall(r'^FROM\s',recipe,re.M|re.I))>=2 and re.search(r'^COPY\s+--from=',recipe,re.M|re.I), 'Use separate build and final stages'
    build=run(['docker','build','--network=none','--no-cache','-t','training-built:graded','/srv/build'],timeout=180)
    assert build.returncode==0, 'The Dockerfile must build without downloading dependencies: '+build.stderr[-300:]
    spec=json.loads(run(['docker','image','inspect','training-built:graded']).stdout)[0]
    assert spec['Size'] < 10*1024*1024, 'Keep the final image below 10 MiB'
    assert spec['Config']['User'] in ('65532','65532:65532'), 'Set the image user to UID 65532'
    container='build-proof-'+uuid.uuid4().hex[:8]
    created=run(['docker','create','--name',container,'--read-only','--cap-drop=ALL','--security-opt=no-new-privileges','-p','127.0.0.1::8080','training-built:graded'])
    if created.returncode: raise RuntimeError(created.stderr)
    try:
        archive=subprocess.run(['docker','export',container],capture_output=True,timeout=30)
        if archive.returncode: raise RuntimeError(archive.stderr.decode())
        with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as tar:
            names=[m.name.lstrip('./') for m in tar]
        assert 'server' in names, 'Include the compiled server'
        assert not any(n.endswith(('/gcc','/cc','/sh','/bash','server.c')) for n in names), 'Exclude compilers, shells and source from the final filesystem'
        if outcome=='running-image':
            start=run(['docker','start',container])
            if start.returncode: raise RuntimeError(start.stderr)
            address=run(['docker','port',container,'8080/tcp']).stdout.strip()
            deadline=time.monotonic()+10
            while True:
                try:
                    with urllib.request.urlopen('http://'+address,timeout=2) as reply: body=reply.read()
                    break
                except OSError:
                    if time.monotonic()>deadline: raise AssertionError('The restricted container must serve HTTP')
                    time.sleep(0.5)
            assert body==b'built-service\n', 'Preserve the application response'
            pid=json.loads(run(['docker','inspect',container]).stdout)[0]['State']['Pid']
            status=pathlib.Path('/proc/'+str(pid)+'/status').read_text()
            assert re.search(r'^Uid:\s+65532\s+65532\s+65532\s+65532$',status,re.M), 'The running process must have UID 65532'
        elif outcome!='built-image': raise RuntimeError('Unknown outcome')
    finally: run(['docker','rm','-f',container])

if __name__ == '__main__':
    try:
        check(sys.argv[1])
    except AssertionError as error:
        print('FAIL:', error); sys.exit(1)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print('ERROR:', error); sys.exit(2)
    print('PASS:', sys.argv[1])

PY_CHECK
