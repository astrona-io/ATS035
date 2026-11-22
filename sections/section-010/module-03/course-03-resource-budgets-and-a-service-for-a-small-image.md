---
exam_objectives:
- Minimize base image footprint
---
# Resource Budgets And A Service For A Small Image

A size budget limits how large an image may grow on disk. A running container also needs a budget, for the CPU time and the memory that it may use on the node. Without one, a small server can still take memory from every other pod on the node. This part runs a minimal BusyBox web server as a Deployment with CPU and memory requests and a memory limit, and makes it reachable through a Service.

## Requests, limits and the kubelet

A container has two kinds of resource settings in its `resources` field. A request is the amount that the container needs. The scheduler uses the requests to choose a node that still has that much room. A limit is the most that the container may use. The kubelet, the node agent, passes the limits to the container runtime, and the runtime writes them into the Linux control group (cgroup) of the container. A cgroup is the kernel feature that counts and caps the CPU and memory of a group of processes.

The two resources behave differently at their limits. A container that reaches its CPU limit is slowed down, because the kernel gives it less CPU time. A container that reaches its memory limit cannot get more memory, so the kernel stops a process in it, and the pod status shows the reason `OOMKilled` (out of memory). A memory limit therefore protects the other pods on the node, and a CPU request makes sure that the container gets its share. Many teams set a memory limit and leave out the CPU limit, so that a container can use idle CPU time.

<!-- astrona:playground:renew -->

Select the playground cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-010-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-010-03" || exit 1
```

The probe Deployment in the playground already has a budget. Read it first:

```sh
kubectl -n starfleet get deployment probe -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

The output is a JSON object with `requests` for `cpu` and `memory` and a `limits` object with only `memory`. The probe container asks for `10m` of CPU, which is one hundredth of a CPU core, and `32Mi` of memory, and it may use at most `128Mi` of memory.

## Run a minimal web server as a Deployment

A single pod is gone for good when its node fails. A Deployment is a controller object that keeps a set number of identical pods running from a pod template, and it replaces a pod that stops. The next file holds a ConfigMap with one page and a Deployment that serves that page with the `httpd` server of BusyBox. The container port has the name `http`, so other objects can refer to the port by its name instead of its number.

Save this as `deployment-tiny-web.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tiny-site
  namespace: starfleet
data:
  index.html: |
    tiny-web-version=v1
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tiny-web
  namespace: starfleet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tiny-web
  template:
    metadata:
      labels:
        app: tiny-web
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: web
        image: docker.io/library/busybox:1.37.0
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
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: site
          mountPath: /site
          readOnly: true
      volumes:
      - name: site
        configMap:
          name: tiny-site
```

Apply it:

```sh
kubectl apply -f deployment-tiny-web.yaml
```

Then check the result. The Deployment controller creates a ReplicaSet, and the ReplicaSet creates the pod:

```sh
kubectl -n starfleet rollout status deployment/tiny-web --timeout=120s
kubectl -n starfleet get pod -l app=tiny-web -o jsonpath='{.items[0].status.qosClass}{"\n"}'
```

The rollout command reports that the Deployment `tiny-web` was successfully rolled out. The second command prints `Burstable`. Kubernetes gives each pod a quality of service (QoS) class from its requests and limits. A pod is `Guaranteed` only when every container sets equal requests and limits for both CPU and memory. This pod sets requests and only a memory limit, so it is `Burstable`. When the node runs low on memory, the kubelet first evicts pods that use more memory than they requested. A `BestEffort` pod has no requests at all, so any use counts as more than its request.

The memory limit is not only a field in the API. The container runtime wrote it into the cgroup of the container, and you can read it from inside the container:

```sh
kubectl -n starfleet exec deploy/tiny-web -- cat /sys/fs/cgroup/memory.max
```

The command prints `67108864`. That number is 64 multiplied by 1024 twice, so it is exactly `64Mi` in bytes. The file belongs to cgroup version 2, which the playground nodes use. The kernel, not Kubernetes, stops a process in the container when it goes past this number.

## Reach the pods through a Service

A pod gets a new IP address each time the Deployment replaces it, so a client cannot keep a pod address. A Service is an object with a stable virtual IP address and a DNS name. It selects pods by their labels and sends each connection to one of them. The `targetPort` of a Service can name a container port. The Service then follows the port name, so the pod can change its port number without a change to the Service.

Save this as `service-tiny-web.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tiny-web
  namespace: starfleet
spec:
  selector:
    app: tiny-web
  ports:
  - name: http
    port: 80
    targetPort: http
```

Apply it:

```sh
kubectl apply -f service-tiny-web.yaml
```

Then check the result. The first command lists the EndpointSlice that the EndpointSlice controller made for the Service. The second sends a request from the `shuttle` pod to the Service by its name:

```sh
kubectl -n starfleet get endpointslices -l kubernetes.io/service-name=tiny-web
kubectl -n starfleet exec shuttle -- wget -qO- http://tiny-web
```

The EndpointSlice lists port `8080` and the IP address of the `tiny-web` pod. The Service listens on port 80, and the name `http` resolved to the container port 8080. The `wget` command prints `tiny-web-version=v1`. The cluster DNS server answered the name `tiny-web` with the IP address of the Service, because the `shuttle` pod runs in the same namespace. kube-proxy on the node then sent the connection to the pod on port 8080.

You now know how a request and a limit reach the scheduler, the kubelet and the kernel, why a memory limit protects the node, and how a Service with a named target port gives a small server one stable name. The open question is what the budget should be: a limit that is too low stops a healthy process, so measure the real use of the server before you choose the number.

## Common pitfalls

> [!WARNING]
> - **Setting a memory limit lower than the real use.** The kernel stops the process again and again, and the pod shows `OOMKilled` with a growing restart count. Measure first, then set the limit with some room.
> - **A Service selector that does not match the pod labels.** The Service then has no endpoints, and every request fails. Compare the selector with the labels in the pod template.
> - **A `targetPort` name that the container does not declare.** The port name must match a `ports[].name` of the container exactly.
> - **Expecting a CPU limit to stop a process.** A CPU limit only slows the container down. Only the memory limit leads to a stopped process.
