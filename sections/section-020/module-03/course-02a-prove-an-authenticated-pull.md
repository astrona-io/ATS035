---
draft: true
---
# Prove An Image Pull Uses Registry Credentials

A correctly shaped pull Secret does not prove that a kubelet used it. Test a fresh Pod against a registry that refuses anonymous access. The independent lab provides a local registry and a failed Pod so the credential change has an observable effect.

The registry account is disposable and the network is private to this environment. Its HTTP endpoint keeps certificate provisioning out of this exercise. Real deployments should use trusted TLS; image pull credentials alone do not encrypt a connection.

<!-- astrona:playground:renew -->

In the independent lab, inspect the supplied endpoint and image:

```sh
namespace=starfleet-035-020-03-01
kubectl -n "$namespace" get configmap registry-info -o yaml
kubectl -n "$namespace" describe pod release-check
```

Use the server value exactly, including its port. The Secret type tells Kubernetes to interpret its data as registry credentials. Create it using the lab's disposable account:

```sh
server=$(kubectl -n "$namespace" get configmap registry-info -o jsonpath='{.data.server}')
kubectl -n "$namespace" create secret docker-registry registry-credentials \
  --docker-server="$server" --docker-username=builder --docker-password=training-password
kubectl -n "$namespace" patch serviceaccount probe-runner --type=merge \
  -p '{"imagePullSecrets":[{"name":"registry-credentials"}]}'
```

The ServiceAccount admission controller copies imagePullSecrets when a Pod is created. Updating the ServiceAccount does not rewrite an existing Pod. Recreate the failed Pod with `serviceAccountName: probe-runner` and the private image shown in registry-info. Specify `imagePullPolicy: Always` so a new launch resolves the image against the registry even when its layers are cached.

Save this as `pod-release-check.yaml`, replacing `<PRIVATE_IMAGE>` with the supplied image:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: release-check
  namespace: starfleet-035-020-03-01
spec:
  serviceAccountName: probe-runner
  restartPolicy: Never
  containers:
    - name: client
      image: <PRIVATE_IMAGE>
      imagePullPolicy: Always
      command: [sh, -c, sleep 36000]
```

Apply the replacement:

```sh
kubectl -n "$namespace" delete pod release-check
kubectl apply -f pod-release-check.yaml
kubectl -n "$namespace" wait --for=condition=Ready pod/release-check --timeout=120s
kubectl -n "$namespace" get pod release-check -o jsonpath='{.spec.imagePullSecrets}'
```

Read the Pod events when a pull fails. An authorization response, a missing image, a certificate failure and a connection timeout require different repairs. The grader repeats the launch with a new Pod so a previously running container cannot hide broken credentials.

## Common pitfalls

> [!WARNING]
> The Secret must exist in the Pod's namespace, and its registry key must match the image's server. Keep registry authentication enabled. A cached or public replacement image does not demonstrate an authenticated pull.
