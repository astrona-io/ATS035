# Checks that verify the Cosign signature of the supplied image digest in the
# loopback registry on the lab VM. check.py runs this file with NODE,
# node_exec(), command() and wants() already defined. The old grader ran as
# root, so every command here runs with sudo too.
import urllib.request

# bootstrap/setup.sh keeps the grader's copies of the references and the key
# hashes here, out of the student's reach.
LIVE = Path('/opt/astrona-live')
SIGNING = Path('/srv/signing')
WRONG_KEY_ERRORS = ('no matching signatures', 'signature verification', 'invalid signature', 'failed to verify signature')
UNSIGNED_ERRORS = ('no signatures', 'no matching signatures', 'no matching attestations', 'not found', 'manifest unknown')


def run(*args):
    return subprocess.run(['sudo', *args], capture_output=True, text=True, timeout=60)


def verify(key, reference):
    return run('cosign', 'verify', '--key', key, '--insecure-ignore-tlog=true', '--allow-insecure-registry', reference)


def check_signature():
    """The supplied digest verifies under the training key and the claims name that digest."""
    try:
        with urllib.request.urlopen('http://127.0.0.1:5000/v2/', timeout=5) as response:
            healthy = response.status == 200
    except OSError:
        healthy = False
    assert healthy, 'The registry must remain available'
    assert run('sha256sum', '-c', str(LIVE / 'keys.sha256')).returncode == 0, 'Preserve both trust keys'
    image = run('cat', str(LIVE / 'image.txt')).stdout.strip()
    assert (SIGNING / 'image.txt').read_text().strip() == image, 'Preserve the supplied image digest'
    accepted = verify(str(SIGNING / 'training.pub'), image)
    assert accepted.returncode == 0, 'Sign the exact supplied image digest with the training key'
    signatures = json.loads(accepted.stdout)
    assert signatures and all(item['critical']['image']['docker-manifest-digest'] == image.split('@')[1] for item in signatures), 'The verified claims must bind the image digest'
    return image


def check_boundary(image):
    """The same digest fails under another key, and an unsigned digest fails under the training key."""
    wrong = verify(str(LIVE / 'other.pub'), image)
    assert wrong.returncode != 0 and any(text in wrong.stderr.lower() for text in WRONG_KEY_ERRORS), 'Reject the signed image under an unrelated public key'
    unsigned = run('cat', str(LIVE / 'unsigned.txt')).stdout.strip()
    absent = verify(str(SIGNING / 'training.pub'), unsigned)
    assert absent.returncode != 0 and any(text in absent.stderr.lower() for text in UNSIGNED_ERRORS), 'Reject the unsigned image under the trusted key'


# The trust boundary only means something once a valid signature exists, so
# both outcomes first need the accepted signature.
image_signature = wants('image-signature')
trust_boundary = wants('trust-boundary')
if image_signature or trust_boundary:
    image = check_signature()
    if trust_boundary:
        check_boundary(image)
