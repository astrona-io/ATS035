---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Make An SBOM Of A Running Image With Syft Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-01-03)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-01-03" || exit 1
```

Keep this connection selected. Every command in this lab runs against this cluster only.

## Find the image that runs

A tag such as `3.13-alpine` can point to a new image tomorrow. The kubelet reports the image that it actually started in the pod status, in the `imageID` field, as a repository name and a digest. A digest is the SHA-256 hash of the image manifest, so it names exactly one image. Read it from a ready `probe` pod:

```sh
kubectl -n starfleet-035-020-01-03 get pods -l app=probe \
  -o jsonpath='{.items[0].status.containerStatuses[0].imageID}{"\n"}'
```

The command prints `docker.io/library/python@sha256:` followed by 64 hexadecimal characters. Keep this value; it is `<IMAGE_ID>` in the next two steps. Both replicas show the same value, because both pods started from the same pull.

## Run Syft in a Job

Syft can scan an image from a registry, but here it reads the files of the image from a folder. The init container runs the probe image by its digest, so the kubelet starts exactly the image that the probe pods run. It copies the system folders into an `emptyDir` volume, which is an empty folder that the kubelet creates for the pod. The `syft` container then scans that folder with the `dir:` source and prints the CycloneDX document to its standard output. With `--quiet`, Syft prints nothing else, so the log holds only the JSON.

Save this as `job-sbom-probe.yaml`, and replace `<IMAGE_ID>` with the value from the first step:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sbom-probe
  namespace: starfleet-035-020-01-03
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      initContainers:
      - name: rootfs
        image: <IMAGE_ID>
        imagePullPolicy: IfNotPresent
        command:
        - cp
        - -a
        - /bin
        - /etc
        - /lib
        - /sbin
        - /usr
        - /var
        - /scan/
        volumeMounts:
        - name: scan
          mountPath: /scan
      containers:
      - name: syft
        image: docker.io/anchore/syft:v1.57.0
        imagePullPolicy: IfNotPresent
        args:
        - scan
        - dir:/scan
        - --quiet
        - --output
        - cyclonedx-json
        env:
        - name: SYFT_CHECK_FOR_APP_UPDATE
          value: "false"
        volumeMounts:
        - name: scan
          mountPath: /scan
          readOnly: true
      volumes:
      - name: scan
        emptyDir: {}
```

Apply it:

```sh
kubectl apply -f job-sbom-probe.yaml
```

Then check the result. The Job controller creates one pod; it is complete when the `syft` container exits with code zero:

```sh
kubectl -n starfleet-035-020-01-03 wait --for=condition=Complete job/sbom-probe --timeout=180s
kubectl -n starfleet-035-020-01-03 get pods -l job-name=sbom-probe \
  -o jsonpath='{.items[0].status.initContainerStatuses[0].imageID}{"\n"}'
```

The `wait` command reports that the Job met the `Complete` condition. The second command prints the image ID of the init container, and it is the same value as the `imageID` of the probe pods. That match ties the scanned files to the running image.

## Read and store the SBOM

The log of the `syft` container is the SBOM. Save it as a file and read the header and the Alpine packages:

```sh
kubectl -n starfleet-035-020-01-03 logs job/sbom-probe -c syft > probe.cdx.json
jq -c '{bomFormat, specVersion, tools: [.metadata.tools.components[] | "\(.name) \(.version)"]}' probe.cdx.json
jq -r '.components[] | select(.purl // "" | startswith("pkg:apk/")) | "\(.name)@\(.version)"' probe.cdx.json | sort
```

The first `jq` command shows `"bomFormat":"CycloneDX"` and the tool `syft 1.57.0`. The second lists each Alpine package with its version, for example `musl@1.2.6-r3`; your versions can differ, because the tag moves when the Python image is rebuilt. Syft also lists Python packages such as `pip`, and one component of type `file` for each file it catalogued, so the document is several hundred kilobytes.

Store the document together with the image ID. `kubectl create configmap` sends the file in the request body. `kubectl apply` would also store the whole object in an annotation, which is limited to 262144 bytes, so it fails for a large SBOM:

```sh
kubectl -n starfleet-035-020-01-03 create configmap probe-sbom \
  --from-file=sbom.cdx.json=probe.cdx.json \
  --from-literal=runtimeImageID='<IMAGE_ID>'
kubectl -n starfleet-035-020-01-03 get configmap probe-sbom -o jsonpath='{.data.runtimeImageID}{"\n"}'
```

The last command prints the digest reference. The ConfigMap now answers two questions from an incident review: which image ran, and which packages were inside it. A ConfigMap is fine for this lab; a real pipeline stores the SBOM in the artifact repository next to the image, often as a signed attestation.

After recording your result, remove the lab with `astrona destroy ats-035-lab-020-01-03`.

## Common pitfalls

> [!WARNING]
> - **Scanning the tag instead of the digest.** A tag can move between the scan and the incident. Use the `imageID` from the pod status as the image of the init container.
> - **Dropping `--quiet`.** Without it, Syft can print log messages into the same log, and the saved file is no longer valid JSON.
> - **Storing a large SBOM with `kubectl apply`.** The `last-applied-configuration` annotation is limited to 262144 bytes. Use `kubectl create configmap --from-file`.
> - **Treating an SBOM as a vulnerability result.** An SBOM lists components. A scanner such as Trivy matches that list against vulnerability data.
