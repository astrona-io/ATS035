---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Scan An Image And Bind The Release Decision Solution

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-040-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-040-02-02`. You are logged in as the `student` user. The VM runs Docker and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Docker and Trivy. The Docker daemon and the Trivy cache belong to root, so run `docker` and `trivy` with `sudo`. These commands change only the lab VM, not your own computer.

## Look at the evidence inputs

A report is only useful as release evidence when it names the image it scanned and the database it used. Print the image ID and the database metadata:

```sh
sudo docker image inspect alpine:3.18.0 --format '{{.Id}}'
sudo cat /var/cache/trivy-training/db/metadata.json
```

The image ID is the SHA-256 hash of the image configuration. `UpdatedAt` in the metadata is the time the database was built.

## Run the scan

Scan the image from the Docker image cache with the lab database:

```sh
sudo trivy image --cache-dir /var/cache/trivy-training --skip-db-update --offline-scan --image-src docker --scanners vuln --format json --output /srv/scan/report.json alpine:3.18.0
```

`--skip-db-update` keeps the downloaded database, and `--offline-scan` stops extra lookups on the network. `--scanners vuln` limits the report to vulnerabilities. Do not add `--severity` or `--ignore-unfixed`: the grader compares the whole list of findings.

## Write the decision

Save this as `decision.py`:

```python
import json,pathlib
report=json.loads(pathlib.Path('/srv/scan/report.json').read_text())
db=json.loads(pathlib.Path('/var/cache/trivy-training/db/metadata.json').read_text())
count=sum(v['Severity'] in ('HIGH','CRITICAL') for r in report.get('Results',[]) for v in r.get('Vulnerabilities',[]))
pathlib.Path('/srv/scan/decision.json').write_text(json.dumps({'image_id':report['Metadata']['ImageID'],'database_updated_at':db['UpdatedAt'],'high_critical':count,'decision':'block' if count else 'allow'},indent=2)+'\n')
```

Run it and read the result:

```sh
sudo python3 decision.py
cat /srv/scan/decision.json
```

The script counts the findings in every target, including the ones without a fix. With an old Alpine release the count is usually above zero, so the decision is `block`. The grader computes the same values from its own scan.
