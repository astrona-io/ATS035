---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Prerequisites

Use astrona and a terminal. Every command runs in a shell on the lab VM, not on your own computer.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-040-02-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-040-02-02`. You are logged in as the `student` user. The VM runs Docker and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Docker and Trivy. The Docker daemon and the Trivy cache belong to root, so run `docker` and `trivy` with `sudo`. These commands change only the lab VM, not your own computer.
