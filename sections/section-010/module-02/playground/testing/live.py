user = kubectl('-n', 'starfleet', 'exec', 'restricted-runner', '--', 'id', '-u')
assert user == '10001', 'The process must run as the numeric user 10001'
write_attempt = command(['kubectl', '-n', 'starfleet', 'exec', 'restricted-runner', '--', 'sh', '-c', 'touch /should-fail'], success=False)
assert write_attempt.returncode != 0, 'The root filesystem must be read-only'
