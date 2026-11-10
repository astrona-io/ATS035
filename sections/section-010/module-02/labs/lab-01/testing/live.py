if wants('runtime-enforced'):
    get('pod', 'restricted-runner')
    user = command(['kubectl', '-n', NAMESPACE, 'exec', 'restricted-runner', '--', 'id', '-u'], success=False)
    assert user.stdout.strip() == '10001', 'The process in restricted-runner must run as the numeric user 10001'
    write_attempt = command(['kubectl', '-n', NAMESPACE, 'exec', 'restricted-runner', '--', 'sh', '-c', 'touch /should-fail'], success=False)
    assert write_attempt.returncode != 0, 'The root filesystem of restricted-runner must be read-only'
