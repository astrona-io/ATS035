#!/usr/bin/env bash
set -euo pipefail
sudo python3 /opt/astrona-live/check.py image-signature
sudo python3 /opt/astrona-live/check.py trust-boundary
sudo cp /srv/signing/image.txt /tmp/signed-reference
sudo cp /srv/signing/unsigned.txt /srv/signing/image.txt
set +e
output=$(sudo python3 /opt/astrona-live/check.py image-signature); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Preserve the supplied image digest' ]]
sudo cp /tmp/signed-reference /srv/signing/image.txt
