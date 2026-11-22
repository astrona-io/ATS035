---
exam_objectives:
- Minimize base image footprint
---
# Run A Pinned Web Server With A Resource Budget And A Service Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-010-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-010-03-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Read the digest of the shuttle pod

The kubelet records the content that a container really runs in the `imageID` field of the container status. The node pulled BusyBox from the registry, so the value has the form `docker.io/library/busybox@sha256:` followed by 64 hexadecimal characters. This command prints only the digest:

```sh
kubectl -n starfleet-035-010-03-03 get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}' | sed 's/.*@sha256://'
```

Copy the 64 characters. They replace `<DIGEST>` in the next file.

## Create the page and the Deployment

The ConfigMap holds the page, and the Deployment runs the BusyBox `httpd` server with the ConfigMap mounted read-only at `/site`. The `resources` field gives the container its budget: the scheduler uses the requests to place the pod, and the kubelet passes the memory limit to the container runtime, which writes it into the Linux control group (cgroup) of the container.

Save this as `deployment-minimal-web.yaml`, and replace `<DIGEST>` with the digest from the first step:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minimal-site
  namespace: starfleet-035-010-03-03
data:
  index.html: |
    minimal-web-version=v1
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minimal-web
  namespace: starfleet-035-010-03-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minimal-web
  template:
    metadata:
      labels:
        app: minimal-web
    spec:
      containers:
      - name: web
        image: docker.io/library/busybox@sha256:<DIGEST>
        imagePullPolicy: IfNotPresent
        command:
        - httpd
        - -f
        - -p
        - "8080"
        - -h
        - /site
        ports:
        - name: http
          containerPort: 8080
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            memory: 64Mi
        volumeMounts:
        - name: site
          mountPath: /site
          readOnly: true
      volumes:
      - name: site
        configMap:
          name: minimal-site
```

Apply it:

```sh
kubectl apply -f deployment-minimal-web.yaml
```

Then check the result:

```sh
kubectl -n starfleet-035-010-03-03 rollout status deployment/minimal-web --timeout=180s
kubectl -n starfleet-035-010-03-03 exec deploy/minimal-web -- cat /sys/fs/cgroup/memory.max
```

The rollout command reports that the Deployment `minimal-web` was successfully rolled out. The second command prints `67108864`, which is `64Mi` in bytes. The kernel enforces this number, so the container cannot use more memory than its limit.

## Create the Service

The Service gives the pod a stable name. Its `targetPort` names the container port `http`, so the Service follows the name to port 8080.

Save this as `service-minimal-web.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: minimal-web
  namespace: starfleet-035-010-03-03
spec:
  selector:
    app: minimal-web
  ports:
  - name: http
    port: 80
    targetPort: http
```

Apply it:

```sh
kubectl apply -f service-minimal-web.yaml
```

Then check the result:

```sh
kubectl -n starfleet-035-010-03-03 get endpointslices -l kubernetes.io/service-name=minimal-web
kubectl -n starfleet-035-010-03-03 exec shuttle -- wget -qO- -T 5 http://minimal-web
```

The EndpointSlice lists port `8080` and the IP address of the `minimal-web` pod. The `wget` command prints `minimal-web-version=v1`. The cluster DNS server resolved the name `minimal-web` to the Service IP address, and kube-proxy sent the connection to the pod.

After recording your result, remove the lab with `astrona destroy ats-035-lab-010-03-03`.

## Common pitfalls

> [!WARNING]
> - **Pinning the tag digest from a registry website.** The grader compares the image with the digest in the `imageID` of the `shuttle` pod. Read the digest from the cluster.
> - **Writing the memory limit as `64M`.** `64M` is 64,000,000 bytes, not `64Mi`. Write `64Mi`.
> - **A `targetPort` of `8080` instead of `http`.** The request still works, but the task asks for the named port, so the grader rejects it.
> - **Forgetting the read-only mount.** Set `readOnly: true` on the `/site` volume mount.
