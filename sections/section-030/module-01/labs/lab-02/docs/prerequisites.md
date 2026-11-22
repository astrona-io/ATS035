---
exam_objectives:
- Secure your supply chain (permitted registries, sign and validate artifacts, etc.)
---
# Prerequisites

Use astrona and a terminal. Every command runs in a shell on the lab VM, not on your own computer.

Open a shell on the lab VM (virtual machine) and check that kubectl uses this lab's cluster:

```sh
astrona ssh astro-ats-035-lab-030-01-02
kubectl config current-context
```

The second command prints `kubernetes-admin@astro-ats-035-lab-030-01-02`. You are logged in as the `student` user. The VM runs Docker, a container registry and a one-node Kubernetes cluster built with kubeadm, the standard tool that installs a cluster on a Linux machine. This task uses only Cosign and the registry. These commands change only the lab VM, not your own computer.
