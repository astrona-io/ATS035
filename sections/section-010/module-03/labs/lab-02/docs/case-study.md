---
exam_objectives:
- Minimize base image footprint
---
# Starting Environment

The isolated environment has two healthy `probe` replicas, an internal Service and two client pods. The pod `offline-runner` has `imagePullPolicy: Never` and names `docker.io/library/busybox:1.36.1`, which the node does not hold, so it does not start. The `relay` Deployment runs `docker.io/library/busybox:1.37.0` with `imagePullPolicy: IfNotPresent`.

Repair a pod that may not pull by pointing it at an image the node already holds, and make a Deployment ask the registry each time its container starts.
