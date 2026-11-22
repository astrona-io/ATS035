---
exam_objectives:
- Minimize base image footprint
---
# Prerequisites

Use astrona and a terminal. Every command runs in a shell on the lab VM, not on your own computer.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-010-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-010-01-02`. You are logged in as the `student` user. The VM runs Docker and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Docker. The Docker daemon belongs to root, so run every `docker` command with `sudo`. These commands change only the lab VM, not your own computer.
