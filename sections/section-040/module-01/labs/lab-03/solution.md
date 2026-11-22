---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Score A Live Deployment With Kubesec Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-01-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Read the first report

Kubesec scores the object that it receives. Here it receives the live Deployment from the API server, so the score describes what the cluster actually stores. The `jq` filter at the end keeps the score, the message and the rule IDs of the `critical` and `advise` lists, so the long report fits on one screen:

```sh
kubectl -n starfleet-035-040-01-03 get deployment score-probe -o yaml |
  kubectl -n starfleet-035-040-01-03 exec -i scanner -- kubesec scan - |
  jq '.[0] | {score, message, critical: [.scoring.critical[]?.id], advise: [.scoring.advise[]?.id]}'
```

The score is negative: Kubesec 2.15.0 prints `Failed with a score of -30 points`. The `critical` list holds one rule, `Privileged`, and that rule alone takes away 30 points. The `advise` list names the settings that would add points, for example `RunAsNonRoot`, `RunAsUser`, `ReadOnlyRootFilesystem`, `CapDropAll` and the CPU and memory requests and limits. Kubesec also exits with a non-zero code, which is what would stop a pipeline.

## Fix the Deployment

Each rule in the report points at one field of the pod template. The fix removes the privileged setting, which clears the critical list, and then adds the settings that the `advise` list asks for. The application writes `/tmp/last-run`, so a read-only root file system needs a writable `emptyDir` volume mounted at `/tmp`. An `emptyDir` volume is an empty folder that the kubelet creates for the pod and deletes with it.

Save this as `deployment-score-probe.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: score-probe
  namespace: starfleet-035-040-01-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: score-probe
  template:
    metadata:
      labels:
        app: score-probe
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: docker.io/library/busybox:1.37.0
        imagePullPolicy: IfNotPresent
        command:
        - sh
        - -c
        - while true; do date > /tmp/last-run; sleep 30; done
        securityContext:
          privileged: false
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
            cpu: 100m
            memory: 64Mi
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
```

Apply it:

```sh
kubectl apply -f deployment-score-probe.yaml
```

Then check the result. The Deployment controller starts a new ReplicaSet with the new pod template and removes the old pod:

```sh
kubectl -n starfleet-035-040-01-03 rollout status deployment/score-probe --timeout=180s
kubectl -n starfleet-035-040-01-03 exec deploy/score-probe -- id -u
kubectl -n starfleet-035-040-01-03 exec deploy/score-probe -- cat /tmp/last-run
```

The rollout command reports that the rollout finished. The process runs as user 10001, and `/tmp/last-run` holds the date that the application wrote into the `emptyDir` volume.

## Scan again and record the score

Run the same scan on the live Deployment:

```sh
kubectl -n starfleet-035-040-01-03 get deployment score-probe -o yaml |
  kubectl -n starfleet-035-040-01-03 exec -i scanner -- kubesec scan - |
  jq '.[0] | {score, message, critical: [.scoring.critical[]?.id], advise: [.scoring.advise[]?.id]}'
```

Kubesec 2.15.0 prints `Passed with a score of 12 points` for this Deployment, and the `critical` list is empty. The `advise` list still names `ApparmorAny`, `ServiceAccountName` and `HostUsers`. Each of them would add points, but the task needs only a score of at least 10, so the team leaves them for a later change. Record the score that your scan printed. Replace `12` if your score differs:

```sh
kubectl -n starfleet-035-040-01-03 create configmap kubesec-report \
  --from-literal=object=deployment/score-probe \
  --from-literal=score=12
kubectl -n starfleet-035-040-01-03 get configmap kubesec-report -o jsonpath='{.data}'
```

The ConfigMap holds the object name and the score. The grader scans the live Deployment again and compares the two numbers, so a later change to the Deployment that moves the score also makes the record out of date. A high score still says nothing about the packages inside `busybox:1.37.0`; that needs an image scan.

After recording your result, remove the lab with `astrona destroy ats-035-lab-040-01-03`.

## Common pitfalls

> [!WARNING]
> - **Scanning a local file instead of the live object.** The cluster may hold a different version. Pipe `kubectl get -o yaml` into Kubesec, or scan the rendered manifest that you apply.
> - **Reading only the score.** A score can go up while a critical finding stays. Check that the `critical` list is empty first, then read the score.
> - **Making the root file system read-only without a writable folder.** The application then fails to write `/tmp/last-run` and the pod keeps restarting. Mount an `emptyDir` volume at the path that the application writes.
> - **Recording an old score.** Scan again after the rollout, then write that number into the ConfigMap.
