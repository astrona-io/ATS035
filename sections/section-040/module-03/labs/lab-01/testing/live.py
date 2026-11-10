if wants('privileged-rejected'):
    rejected = command(['kubectl', '-n', 'hangar-035-040-03-01', 'apply', '--dry-run=server', '-f', str(DIRECTORY / 'unrestricted-reader.yaml')], success=False)
    assert rejected.returncode != 0 and 'violates PodSecurity' in rejected.stdout + rejected.stderr, 'Pod Security Admission must reject the privileged pod in hangar-035-040-03-01'
    assert kubectl('-n', 'hangar-035-040-03-01', 'get', 'pod', 'unrestricted-reader', '--ignore-not-found', '-o', 'name') == '', 'Do not create the unrestricted pod'
