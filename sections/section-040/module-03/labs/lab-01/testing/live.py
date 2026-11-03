rejected = command(['kubectl', '-n', 'hangar', 'apply', '--dry-run=server', '-f', str(DIRECTORY / 'unrestricted-reader.yaml')], success=False)
assert rejected.returncode != 0 and 'violates PodSecurity' in rejected.stdout + rejected.stderr, 'Pod Security Admission must reject the unrestricted pod'
assert kubectl('-n', 'hangar', 'get', 'pod', 'unrestricted-reader', '--ignore-not-found', '-o', 'name') == '', 'Do not create the unrestricted pod'
