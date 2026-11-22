---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Scan An Image And Bind The Release Decision

Allow about 15 minutes for the tasks.

A release gate needs a vulnerability report for the exact image it ships and a decision that names the database it used. Produce both for the cached `alpine:3.18.0` image.

## Starting state

Docker has `alpine:3.18.0` in its local image cache. This is an old Alpine release, chosen so that the scan finds real vulnerabilities. Trivy, a scanner that lists the known vulnerabilities of the packages in an image, is installed. The VM downloaded a Trivy vulnerability database to `/var/cache/trivy-training` when it started. `/srv/scan` is empty.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-040-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-040-02-02`. You are logged in as the `student` user. The VM runs Docker and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Docker and Trivy. The Docker daemon and the Trivy cache belong to root, so run `docker` and `trivy` with `sudo`. These commands change only the lab VM, not your own computer.

## Tasks

1. Scan the Docker image `alpine:3.18.0` for vulnerabilities with the cache directory `/var/cache/trivy-training`, without a database update and in offline mode. Save the complete Trivy JSON report as `/srv/scan/report.json`.
2. Save `/srv/scan/decision.json` with exactly the keys `image_id`, `database_updated_at`, `high_critical` (an integer) and `decision`. Count every HIGH or CRITICAL finding in all targets. The decision is `block` when the count is not zero, otherwise `allow`. Take the image ID from the report and `UpdatedAt` from `/var/cache/trivy-training/db/metadata.json`.

## Constraints

Do not change the cached image, the scanner or the database. Do not filter out fixed or unfixed vulnerabilities, and keep the whole report. The database must be at most 72 hours old; if it is older, recreate the lab before you start.

## How the answer is checked

The grader runs Trivy again on the current image with the same database. It compares the image ID, the scan targets and every vulnerability with its package, version, fix and severity. Then it counts the HIGH and CRITICAL findings itself and compares the result with `decision.json`. The number of findings changes when the database changes, so no fixed count is expected.
