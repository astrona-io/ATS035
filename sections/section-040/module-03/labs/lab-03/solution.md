---
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Release A Workload Through Analysis, A Scan Gate And Restricted Admission Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-040-03-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-040-03-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Analyse the workload document

A static review reads a document before anything runs. The document is JSON inside a ConfigMap, so `jq` can pull out the three places that matter for security: the image, the pod `securityContext` and the container `securityContext`:

```sh
kubectl -n starfleet-035-040-03-03 get configmap analysis-source -o jsonpath='{.data.workload\.json}' |
  jq '{image: .spec.containers[0].image, pod: .spec.securityContext, container: .spec.containers[0].securityContext}'
```

The image is `docker.io/library/busybox:latest`, so the tag is `latest`. A `latest` tag can point to a new image at any time, so the review cannot say which image would run. The pod has no `securityContext` at all, so `runAsNonRoot` is missing. The container `securityContext` holds only `privileged: true`, so `allowPrivilegeEscalation` is missing too. Record the four facts:

```sh
kubectl -n starfleet-035-040-03-03 create configmap analysis-findings \
  --from-literal=privileged=true \
  --from-literal=runAsNonRoot=missing \
  --from-literal=allowPrivilegeEscalation=missing \
  --from-literal=imageTag=latest
```

## Decide the scan gate

The gate applies the same rules as `trivy image --severity HIGH,CRITICAL --ignore-unfixed` with an ignore file, but on a saved report. Print each finding as one line with its identifier, severity and fixed version, then print the ignore list:

```sh
kubectl -n starfleet-035-040-03-03 get configmap scan-results -o jsonpath='{.data.results\.json}' |
  jq -r '.Results[].Vulnerabilities[] | [.VulnerabilityID, .Severity, (if .FixedVersion == "" then "-" else .FixedVersion end)] | @tsv'
kubectl -n starfleet-035-040-03-03 get configmap scan-exceptions -o jsonpath='{.data.trivyignore\.txt}'
```

Walk the five findings in order. `FIXTURE-0001` is `CRITICAL` with a fixed version, and it is not on the ignore list, so it blocks. `FIXTURE-0002` is `HIGH` with a fixed version, so it blocks too. `FIXTURE-0003` is `CRITICAL` but has no fixed version, so it is unfixed. `FIXTURE-0004` is `LOW`, so the gate does not count it. `FIXTURE-0005` is `HIGH` with a fixed version, but the ignore list names it, so it is waived. Two blocking findings remain, so the decision is `fail`:

```sh
kubectl -n starfleet-035-040-03-03 create configmap scan-gate \
  --from-literal=decision=fail \
  --from-literal=blocking=FIXTURE-0001,FIXTURE-0002 \
  --from-literal=waived=FIXTURE-0005 \
  --from-literal=unfixed=FIXTURE-0003 \
  --from-literal=severity=HIGH,CRITICAL \
  --from-literal=ignoreUnfixed=true
```

A `fail` gate stops this image from release until the team updates the two packages or records a reviewed exception. The unfixed finding stays in the full report, and the team tracks it separately.

## Enforce restricted admission

Pod Security Admission reads the labels of the namespace. The `enforce` label rejects a pod that breaks the standard, `warn` returns a warning to the client and `audit` adds an annotation to the audit log event. The `enforce-version` label pins the rules of Kubernetes v1.35, so a later upgrade does not change them silently. Add the four labels:

```sh
kubectl label namespace starfleet-035-040-03-03 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.35 \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
```

Now test the document from the review without creating it. A server-side dry run sends the request through admission but does not store the object:

```sh
kubectl -n starfleet-035-040-03-03 get configmap analysis-source -o jsonpath='{.data.workload\.json}' > workload.json
kubectl apply --dry-run=server -f workload.json
```

The API server rejects the request, and the error message contains `violates PodSecurity "restricted:v1.35"` followed by the rules that the document breaks. The static review and admission agree: the same missing and unsafe fields appear in both.

## Run the corrected pod

The corrected pod sets every field that the restricted standard needs. Save this as `pod-corrected-reader.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: corrected-reader
  namespace: starfleet-035-040-03-03
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: reader
    image: docker.io/library/busybox:1.37.0
    command:
    - sh
    - -c
    - sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
```

Apply it:

```sh
kubectl apply -f pod-corrected-reader.yaml
```

Then check the result:

```sh
kubectl -n starfleet-035-040-03-03 wait --for=condition=Ready pod/corrected-reader --timeout=180s
```

Pod Security Admission accepts the pod without a warning, and the kubelet starts it. The `wait` command reports that the pod met the `Ready` condition. All three checks now hold in one namespace: the findings are recorded, the gate decision is written down, and admission enforces the standard for every new pod.

After recording your result, remove the lab with `astrona destroy ats-035-lab-040-03-03`.

## Common pitfalls

> [!WARNING]
> - **Deploying the document to see what happens.** Use a server-side dry run. It goes through admission and stores nothing.
> - **Counting an unfixed finding as blocking.** With `--ignore-unfixed`, a finding without a fixed version leaves the gate. Record it as unfixed instead.
> - **Waiving before filtering by severity.** Only `HIGH` and `CRITICAL` findings count. A `LOW` finding is neither blocking nor waived.
> - **Forgetting `enforce-version`.** Without it, the rules follow the cluster version and can change after an upgrade.
