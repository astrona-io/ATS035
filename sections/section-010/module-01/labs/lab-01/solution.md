---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Serve Content With A Minimal Runtime Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-01-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-01-01" || exit 1
node_name="astro-ats-035-lab-010-01-01-control-plane"
worker_name="astro-ats-035-lab-010-01-01-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The isolated environment has two healthy probe replicas, an internal Service and two client Pods. The required result has not been configured.

Inspect the current objects before changing them:

```sh
kubectl -n starfleet get pods -o wide
kubectl get nodes -o wide
```

Create minimal-content with index.html containing minimal-version=v1. Run minimal-server using BusyBox 1.37.0 and its httpd process on port 8080 with a read-only content mount. The client must receive the page and the container must not contain a Python interpreter. Image size alone is not a vulnerability assessment.

Save this as `configmap-minimal-content.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minimal-content
  namespace: starfleet
data:
  index.html: 'minimal-version=v1

    '
---
apiVersion: v1
kind: Pod
metadata:
  name: minimal-server
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: web
    image: docker.io/library/busybox:1.37.0
    command:
    - httpd
    - -f
    - -p
    - '8080'
    - -h
    - /site
    volumeMounts:
    - name: site
      mountPath: /site
      readOnly: true
  volumes:
  - name: site
    configMap:
      name: minimal-content
```

Apply the scoped correction:

```sh
kubectl apply -f configmap-minimal-content.yaml
```

## Verify The Result

Observe the actual result. A denied request returns a nonzero status when the denial works, so run it separately from a shell sequence that stops on error. Status convergence and a successful request establish different parts of the result.

```sh
kubectl -n starfleet wait --for=condition=Ready pod/minimal-server --timeout=180s
```

Select an image providing only the required HTTP process and verify its running contents. The commands above deliberately target one environment. Keep its remaining components available so an unrelated failure cannot stand in for the required denial or correction. No example command output is presented as evidence of a completed run. A matching field alone does not establish that a process used it or that a controller reconciled it.

After recording your result, remove the independent lab with `astrona destroy ats-035-lab-010-01-01`.

## Common pitfalls

> [!WARNING]
> Confirm the private context and exact node names before a change. Check the stated scope and live result. Do not change unrelated components to hide the original fault.
