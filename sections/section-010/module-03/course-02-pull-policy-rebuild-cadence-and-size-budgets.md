---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Pull Policy, Rebuild Cadence And Size Budgets

Pinning decides which content a pod asks for. Three other rules decide whether a node downloads it, when the content is replaced, and how large it may grow. This part covers the image pull policy, the rebuild rules after a security fix, size budgets and registry retention.

## When a node pulls an image

The `imagePullPolicy` field of a container has three values:

- `IfNotPresent` pulls only when the node does not already hold the image.
- `Always` asks the registry every time a container starts. If the digest on the node already matches, the node does not download the layers again.
- `Never` never pulls. The container starts only when the image is already on the node.

If you do not set the field, Kubernetes sets it for you. A reference with the tag `latest`, or with no tag and no digest, gets `Always`. Every other reference, including one with a digest, gets `IfNotPresent`. A moving tag with `IfNotPresent` is the risky combination: two nodes that pulled at different times keep different content under the same name.

## Rebuild when the base image changes

An image is a copy of its base at build time. When the publisher fixes a vulnerability in the base image, your image does not change, because it still holds the old layers. The fix reaches your workload only after three steps: the image is rebuilt on the new base, the new digest is published, and the workload is redeployed with it.

Plan the rebuild in two triggers:

- A **schedule**, for example weekly, rebuilds every image on the newest base even when no one reports a problem.
- A **finding**, such as a scanner report of a fixed critical vulnerability, rebuilds the affected images at once.

A rebuild is only a fix if the build pulls the current base. Build commands that reuse a cached base layer keep the old content, so pipelines pull the base explicitly before building.

## Size budgets and what stays out of the image

A size budget is a limit that a pipeline checks, for example "the final image must stay below 50 megabytes". A budget makes growth visible in review: a new dependency that adds 200 megabytes fails the build and starts a discussion. A `.dockerignore` file lists files that the build context must not send to the builder, such as `.git`, local environment files and test data. It keeps secrets and unneeded files out of the build and speeds it up.

Registries need rules as well. A retention rule deletes images that are older than a set age or beyond a count, so thousands of old, vulnerable builds do not stay available for pulling. An immutable-tag setting refuses a second push to an existing tag, which stops the tag from moving.

## See the pull policy work

You check which images the worker node holds and then start a pod that may not pull.

<!-- astrona:playground:renew -->

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-010-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-010-03" || exit 1
worker_name="astro-ats-035-playground-010-03-worker"
```

List the images on the worker node with their digests. This command runs only inside the node container of this playground:

```sh
podman exec "$worker_name" crictl images --digests
```

Find the BusyBox and Python rows. The rows show the repository, the tag, the digest and the size on the node.

Save this as `pod-never-pull.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: never-pull
  namespace: starfleet
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: docker.io/library/busybox:9.9.9
    imagePullPolicy: Never
    command:
    - sh
    - -c
    - sleep 60
```

Apply it:

```sh
kubectl apply -f pod-never-pull.yaml
```

Then check the result:

```sh
kubectl -n starfleet get pod never-pull
kubectl -n starfleet describe pod never-pull | tail -n 8
```

The pod does not start. Its status shows `ErrImageNeverPull`, and the events say that the image is not present on the machine with a pull policy of `Never`. The node never contacted a registry. Delete the pod when you have read the events:

```sh
kubectl -n starfleet delete pod never-pull
```

You can now explain when a node pulls, why a pinned or old image needs an owner, and how rebuild rules, size budgets and retention keep a minimal image minimal. The next task asks you to pin an image to the digest a node reports.

## Common pitfalls

> [!WARNING]
> - **Using a moving tag with `IfNotPresent`.** Nodes keep whatever they pulled first. Pin a digest or use a unique tag for each build.
> - **Rebuilding with a cached base layer.** The build repeats the old content. Pull the base image before the build.
> - **Setting `Never` to avoid downloads.** The pod fails on every node that lacks the image.
