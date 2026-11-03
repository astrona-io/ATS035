---
draft: true
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Give A Service Account Registry Pull Access Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-03-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-03-01" || exit 1
node_name="astro-ats-035-lab-020-03-01-control-plane"
worker_name="astro-ats-035-lab-020-03-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods and a ServiceAccount named probe-runner. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create the Secret registry-credentials of type kubernetes.io/dockerconfigjson in starfleet for the registry registry.example.test with the user builder and the password s3cret-pull-token. Add the secret to the imagePullSecrets of the existing ServiceAccount probe-runner. Run a pod named release-check with the service account probe-runner and the image docker.io/library/busybox:1.37.0 that runs sleep 3600. The pod must receive the pull secret through its service account, not through a pod-level setting. The registry host and the credential are examples; this task shows how pull access is configured and does not pull from that host.

Save this as `registry-pull-access.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: starfleet
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: '{"auths":{"registry.example.test":{"username":"builder","password":"s3cret-pull-token","auth":"YnVpbGRlcjpzM2NyZXQtcHVsbC10b2tlbg=="}}}'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: probe-runner
  namespace: starfleet
imagePullSecrets:
- name: registry-credentials
---
apiVersion: v1
kind: Pod
metadata:
  name: release-check
  namespace: starfleet
spec:
  serviceAccountName: probe-runner
  restartPolicy: Never
  containers:
  - name: client
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
```

Apply it:

```sh
kubectl apply -f registry-pull-access.yaml
```

## Verify The Result

Observe the actual result. Status convergence and matching fields establish different parts of the result, so check both.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/release-check --timeout=180s
```

Then check the result:

```sh
kubectl -n starfleet get serviceaccount probe-runner -o jsonpath='{.imagePullSecrets[*].name}{"\n"}'
kubectl -n starfleet get pod release-check -o jsonpath='{.spec.imagePullSecrets[*].name}{"\n"}'
```

Create a registry pull secret, attach it to a service account and run a pod that receives it. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-035-lab-020-03-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
