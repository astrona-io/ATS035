---
draft: true
---
# Use A Fresh Scan As Release Evidence

A saved vulnerability report can be accurate for the wrong image or an old database. This independent VM downloads a Trivy database when it starts, then keeps that snapshot fixed while you and the grader scan the same cached image. A fixed snapshot makes the comparison reproducible within the lab; it is not permission to keep using an outdated database in a release pipeline.

<!-- astrona:playground:renew -->

Inspect the image identity and database timestamp inside the VM:

```sh
sudo docker image inspect alpine:3.18.0 --format '{{.Id}}'
sudo cat /var/cache/trivy-training/db/metadata.json
```

The exercise uses an old Alpine release to provide realistic findings. Do not deploy it as a production recommendation. Run the scan:

```sh
sudo trivy image --cache-dir /var/cache/trivy-training --skip-db-update --offline-scan --image-src docker --scanners vuln --format json --output /srv/scan/report.json alpine:3.18.0
```

`--scanners vuln` restricts this report to vulnerabilities. `--skip-db-update` preserves the downloaded snapshot, while `--offline-scan` avoids extra dependency lookups. Neither option makes an old database fresh. The lab refuses evidence once its database is older than 72 hours.

Save this as `decision.py` and run it with `sudo python3 decision.py`:

```python
import json,pathlib
report=json.loads(pathlib.Path('/srv/scan/report.json').read_text())
db=json.loads(pathlib.Path('/var/cache/trivy-training/db/metadata.json').read_text())
count=sum(v['Severity'] in ('HIGH','CRITICAL') for r in report.get('Results',[]) for v in r.get('Vulnerabilities',[]))
pathlib.Path('/srv/scan/decision.json').write_text(json.dumps({'image_id':report['Metadata']['ImageID'],'database_updated_at':db['UpdatedAt'],'high_critical':count,'decision':'block' if count else 'allow'},indent=2)+'\n')
```

The image ID ties the findings to image content. The database timestamp identifies the knowledge used for the decision. The count covers all targets and includes vulnerabilities without a fix. This exercise's release rule blocks any HIGH or CRITICAL finding; a production policy may add documented exceptions and deadlines, which are outside this task.

## Common pitfalls

> [!WARNING]
> A zero exit status from a scanner does not necessarily mean there were no vulnerabilities. Read its findings or configure an explicit exit-code policy. Do not substitute a saved report from another image, omit scan targets, or claim an end-of-life image is safe because a particular database returned no findings.
