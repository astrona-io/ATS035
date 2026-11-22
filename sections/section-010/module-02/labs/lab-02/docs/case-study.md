---
exam_objectives:
- Minimize base image footprint
---
# Starting Environment

The isolated environment has two healthy `probe` replicas on `docker.io/library/python:3.13-alpine`, an internal Service `probe`, the `shuttle` pod on `docker.io/library/busybox:1.37.0` and the `beacon` Deployment. The `beacon` container runs a shell loop that sends a request to the `probe` Service every five seconds and prints the response. It runs on the Python image, although it uses only the shell and `wget`. The ConfigMap `base-image-report` does not exist.

Read what the Alpine based probe image contains, then move a shell-only workload from that image to the smaller BusyBox image and show that it still works.
