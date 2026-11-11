---
draft: true
---
# Solution

The following commands repair the credential and recreate the Pod so admission copies the ServiceAccount setting.

```sh
namespace=starfleet-035-020-03-01
address=$(kubectl -n "$namespace" get configmap registry-info -o jsonpath='{.data.server}')
image=$(kubectl -n "$namespace" get configmap registry-info -o jsonpath='{.data.image}')
kubectl -n "$namespace" create secret docker-registry registry-credentials --docker-server="$address" --docker-username=builder --docker-password=training-password --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$namespace" patch serviceaccount probe-runner --type=merge -p '{"imagePullSecrets":[{"name":"registry-credentials"}]}'
kubectl -n "$namespace" delete pod release-check --wait=true
kubectl -n "$namespace" run release-check --image="$image" --restart=Never --overrides='{"spec":{"serviceAccountName":"probe-runner","containers":[{"name":"client","image":"'"$image"'","imagePullPolicy":"Always","command":["sh","-c","sleep 36000"]}]}}'
kubectl -n "$namespace" wait --for=condition=Ready pod/release-check --timeout=180s
```

Inspect the Pod events and inherited imagePullSecrets. The new Pod must be Ready with the private image. Keep the registry authentication enabled.
