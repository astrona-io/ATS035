---
draft: true
---
# Solution

Run the complete scan:

```sh
sudo trivy image --cache-dir /var/cache/trivy-training --skip-db-update --offline-scan --image-src docker --scanners vuln --format json --output /srv/scan/report.json alpine:3.18.0
```

Calculate the decision using the preparation lesson's Python script. Preserve all report targets and findings; the grader recomputes them.
