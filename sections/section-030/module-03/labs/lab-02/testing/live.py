ADMISSION_DIRECTORY = '/etc/kubernetes/admission'
CONFIG_FILE = ADMISSION_DIRECTORY + '/admission-config.yaml'
BACKEND_KUBECONFIG = ADMISSION_DIRECTORY + '/backend.kubeconfig'
BACKEND_SERVER = 'https://127.0.0.1:9443/image-review'
# Prints the command line of every kube-apiserver process on the node.
APISERVER_PROCESSES = (
    "for directory in /proc/[0-9]*; do "
    "line=$(tr '\\000' ' ' < \"$directory/cmdline\" 2>/dev/null) || continue; "
    "case \"$line\" in 'kube-apiserver '*) printf '%s\\n' \"$line\";; esac; done"
)


def flag_values(arguments, flag):
    """The comma-separated values of one flag, or an empty list when it is missing."""
    prefix = flag + '='
    values = [argument[len(prefix):] for argument in arguments if argument.startswith(prefix)]
    values += [following for argument, following in zip(arguments, arguments[1:]) if argument == flag]
    return [value for item in values for value in item.split(',')]


def node_file_lines(path):
    """The lines of a file on the control plane node, without comments and indentation."""
    result = node_exec(NODE, 'cat', path, success=False)
    assert result.returncode == 0, 'Missing ' + path + ' on the control plane node'
    return [line.split('#')[0].strip() for line in result.stdout.splitlines()]


if wants('plugin-enabled'):
    processes = [line.split() for line in node_exec(NODE, 'sh', '-c', APISERVER_PROCESSES).stdout.splitlines() if line.strip()]
    assert processes, 'No kube-apiserver process runs on the control plane node'
    for arguments in processes:
        plugins = flag_values(arguments, '--enable-admission-plugins')
        assert 'ImagePolicyWebhook' in plugins, 'The running kube-apiserver has no ImagePolicyWebhook in --enable-admission-plugins'
        assert 'NodeRestriction' in plugins, 'Keep NodeRestriction in --enable-admission-plugins'
        assert 'ImagePolicyWebhook' not in flag_values(arguments, '--disable-admission-plugins'), 'The running kube-apiserver disables ImagePolicyWebhook'
        assert flag_values(arguments, '--admission-control-config-file') == [CONFIG_FILE], 'The running kube-apiserver must use --admission-control-config-file=' + CONFIG_FILE
    copies = node_exec(NODE, 'sh', '-c', "grep -lE '^[[:space:]]*- kube-apiserver[[:space:]]*$' /etc/kubernetes/manifests/* 2>/dev/null", success=False).stdout.split()
    assert copies == ['/etc/kubernetes/manifests/kube-apiserver.yaml'], 'Leave only kube-apiserver.yaml in /etc/kubernetes/manifests, no backup copy: found %s' % copies
    assert kubectl('get', '--raw=/readyz', '--request-timeout=10s') == 'ok', 'The API server is not ready'

if wants('default-deny'):
    lines = node_file_lines(CONFIG_FILE)
    assert 'name: ImagePolicyWebhook' in lines or '- name: ImagePolicyWebhook' in lines, CONFIG_FILE + ' must configure the ImagePolicyWebhook plugin'
    assert 'kubeConfigFile: ' + BACKEND_KUBECONFIG in lines, CONFIG_FILE + ' must keep kubeConfigFile: ' + BACKEND_KUBECONFIG
    assert 'defaultAllow: false' in lines and 'defaultAllow: true' not in lines, CONFIG_FILE + ' must set defaultAllow: false'
    assert 'server: ' + BACKEND_SERVER in node_file_lines(BACKEND_KUBECONFIG), 'Keep the backend address in ' + BACKEND_KUBECONFIG + ' unchanged'

if wants('pod-rejected'):
    attempt = command(['kubectl', '-n', NAMESPACE, 'run', 'image-check', '--image=docker.io/library/busybox:1.37.0',
                       '--restart=Never', '--dry-run=server', '--request-timeout=15s', '-o', 'name'], success=False)
    answer = (attempt.stdout + attempt.stderr).lower()
    assert attempt.returncode != 0, 'The API server admitted a new pod: the image policy check is off or fails open'
    assert 'forbidden' in answer and '127.0.0.1:9443' in answer, 'A new pod was not rejected by the ImagePolicyWebhook backend call: ' + answer.strip()[:200]
