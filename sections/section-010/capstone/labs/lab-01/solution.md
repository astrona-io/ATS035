---
draft: true
exam_objectives:
- Minimize base image footprint
---
# Run A Hardened Minimal Web Server Solution

Use a host shell with the private kubeconfig for this independent kind environment. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-capstone-010)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-capstone-010" || exit 1
node_name="astro-ats-035-capstone-010-control-plane"
worker_name="astro-ats-035-capstone-010-worker"
```

Keep this connection selected. Host-level commands name only this environment's node containers. They do not operate on the host operating system.

## Inspect And Explain

The result combines four controls from the section: a small image, an exact image identity, a restricted process and bounded resources. Start with the identity. The container runtime reports the digest of the BusyBox content in the `imageID` field of the `shuttle` pod status:

```sh
kubectl -n starfleet get pod shuttle -o jsonpath='{.status.containerStatuses[0].imageID}' | sed 's/.*@sha256://'
```

Save this as `deployment-minimal-web.yaml` and replace `<DIGEST>` with the 64 characters from the previous command:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: minimal-site
  namespace: starfleet
data:
  index.html: |
    capstone-version=v1
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minimal-web
  namespace: starfleet
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
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: web
        image: docker.io/library/busybox@sha256:<DIGEST>
        imagePullPolicy: IfNotPresent
        command:
        - httpd
        - -f
        - -p
        - '8080'
        - -h
        - /site
        ports:
        - name: http
          containerPort: 8080
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
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
---
apiVersion: v1
kind: Service
metadata:
  name: minimal-web
  namespace: starfleet
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
kubectl apply -f deployment-minimal-web.yaml
```

## Verify The Result

Wait for the rollout. Then request the page from the `shuttle` pod through the Service name, and read the user ID inside the web server container.

```sh
kubectl -n starfleet rollout status deployment/minimal-web --timeout=180s
kubectl -n starfleet exec shuttle -- wget -q -T 3 -O- http://minimal-web.starfleet.svc.cluster.local/
kubectl -n starfleet exec deploy/minimal-web -- id -u
```

The request returns the line `capstone-version=v1`, and the user ID is 10001. The web server listens on port 8080 because a process without root rights cannot bind a port below 1024.

After recording your result, remove the independent lab with `astrona destroy ats-035-capstone-010`.

## Common pitfalls

> [!WARNING]
> - Mounting the ConfigMap without `readOnly: true` or forgetting that the root filesystem is read-only. The `httpd` process only reads `/site`, so no writable volume is needed.
> - Pointing the Service `targetPort` at a number that the container does not use. Use the named port `http`.
> - Confirm the private context before a change. Do not change unrelated components.
