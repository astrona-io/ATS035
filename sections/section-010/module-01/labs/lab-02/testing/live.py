# Checks that rebuild /srv/build/Dockerfile with Docker on the lab VM and
# run the result. check.py runs this file with NODE, node_exec(), command()
# and wants() already defined. Docker belongs to root, so every Docker
# command runs with sudo.
import io
import re
import tarfile
import time
import urllib.request
import uuid

BUILD = Path('/srv/build')
# bootstrap/setup.sh keeps the grader's copy of the supplied source here.
SOURCE_COPY = Path('/opt/astrona-live/server.c')
IMAGE = 'training-built:graded'


def docker(*args, timeout=60, text=True):
    return subprocess.run(['sudo', 'docker', *args], capture_output=True, text=text, timeout=timeout)


def build_and_create():
    """Rebuild the Dockerfile from scratch and create a restricted container."""
    assert (BUILD / 'server.c').read_bytes() == SOURCE_COPY.read_bytes(), 'Preserve the supplied application source'
    recipe = (BUILD / 'Dockerfile').read_text()
    assert len(re.findall(r'^FROM\s', recipe, re.M | re.I)) >= 2 and re.search(r'^COPY\s+--from=', recipe, re.M | re.I), 'Use separate build and final stages'
    build = docker('build', '--network=none', '--no-cache', '-t', IMAGE, str(BUILD), timeout=180)
    assert build.returncode == 0, 'The Dockerfile must build without downloading dependencies: ' + build.stderr[-300:]
    spec = json.loads(docker('image', 'inspect', IMAGE).stdout)[0]
    assert spec['Size'] < 10 * 1024 * 1024, 'Keep the final image below 10 MiB'
    assert spec['Config']['User'] in ('65532', '65532:65532'), 'Set the image user to UID 65532'
    container = 'build-proof-' + uuid.uuid4().hex[:8]
    created = docker('create', '--name', container, '--read-only', '--cap-drop=ALL', '--security-opt=no-new-privileges',
                     '-p', '127.0.0.1::8080', IMAGE)
    if created.returncode:
        raise RuntimeError(created.stderr)
    return container


def check_filesystem(container):
    archive = docker('export', container, timeout=30, text=False)
    if archive.returncode:
        raise RuntimeError(archive.stderr.decode())
    with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as tar:
        names = [member.name.lstrip('./') for member in tar]
    assert 'server' in names, 'Include the compiled server'
    assert not any(name.endswith(('/gcc', '/cc', '/sh', '/bash', 'server.c')) for name in names), 'Exclude compilers, shells and source from the final filesystem'


def check_running(container):
    start = docker('start', container)
    if start.returncode:
        raise RuntimeError(start.stderr)
    address = docker('port', container, '8080/tcp').stdout.strip().splitlines()[0]
    deadline = time.monotonic() + 10
    while True:
        try:
            with urllib.request.urlopen('http://' + address, timeout=2) as reply:
                body = reply.read()
            break
        except OSError:
            if time.monotonic() > deadline:
                raise AssertionError('The restricted container must serve HTTP')
            time.sleep(0.5)
    assert body == b'built-service\n', 'Preserve the application response'
    pid = json.loads(docker('inspect', container).stdout)[0]['State']['Pid']
    status = node_exec(NODE, 'cat', f'/proc/{pid}/status').stdout
    assert re.search(r'^Uid:\s+65532\s+65532\s+65532\s+65532$', status, re.M), 'The running process must have UID 65532'


# Both outcomes need a fresh build with a minimal filesystem; the second one
# also runs it. One build serves both when the whole lab is graded.
built_image = wants('built-image')
running_image = wants('running-image')
if built_image or running_image:
    container = build_and_create()
    try:
        check_filesystem(container)
        if running_image:
            check_running(container)
    finally:
        docker('rm', '-f', container)
