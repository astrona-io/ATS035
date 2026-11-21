#!/usr/bin/env bash
set -euo pipefail
sudo python3 /opt/astrona-live/check.py built-image
sudo python3 /opt/astrona-live/check.py running-image
sudo cp /srv/build/Dockerfile /tmp/Dockerfile.solved
sudo sed -i 's/USER 65532:65532/USER 0/' /srv/build/Dockerfile
set +e
output=$(sudo python3 /opt/astrona-live/check.py running-image); status=$?
set -e
[[ "$status" == 1 && "$output" == 'FAIL: Set the image user to UID 65532' ]]
sudo cp /tmp/Dockerfile.solved /srv/build/Dockerfile
