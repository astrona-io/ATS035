---
exam_objectives:
- Understand your supply chain (for example SBOM, CI/CD, artifact repositories)
---
# Make An SBOM Of A Running Image In The Cluster

A software bill of materials (SBOM) is a list of the packages and versions inside an image. Syft is a tool that reads an image or a folder and writes that list as an SPDX or CycloneDX document. On a workstation, Syft downloads the image from the registry. A release review often needs more: an SBOM of the exact content that a node runs, made inside the cluster with a tool version that the team has fixed. This part runs Syft from a pinned image in a Kubernetes Job and checks the result against the running pod.

## Copy the image content into a volume

A Job is a controller object that runs a pod until it finishes successfully. The Syft image cannot read the files of another image on its own, so the Job uses two containers that share one volume. An init container runs first and must finish before the main container starts. Here the init container uses the same image as the `probe` pod and copies the folders of that image into an `emptyDir` volume. An `emptyDir` volume is an empty folder that the kubelet creates for the pod and deletes with it. The main container then runs Syft on that folder with `scan dir:/scan`.

<!-- astrona:playground:renew -->

Select the playground cluster:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-020-01)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-020-01" || exit 1
```

The `probe` Deployment runs `docker.io/library/python:3.13-alpine`. Read the image and the image ID of one of its pods first. The image ID is the identifier of the content that the container runtime started:

```sh
kubectl -n starfleet get pod -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].image}{" "}{.items[0].status.containerStatuses[0].imageID}{"\n"}'
```

The first value is the image name from the pod spec. The second value is the image ID. On a node that pulled the image from the registry, the image ID has the form `docker.io/library/python@sha256:` followed by the digest, and you can use that value as the image of the init container. A node that loaded the image from a file, as the playground nodes do, can report only a local `sha256:` value, so the Job below uses the image name and the check at the end compares the two image IDs.

Save this as `job-sbom-probe.yaml`:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sbom-probe
  namespace: starfleet
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      initContainers:
      - name: rootfs
        image: docker.io/library/python:3.13-alpine
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

The `--quiet` flag stops Syft from printing progress, so the container log holds only the CycloneDX document. The environment variable `SYFT_CHECK_FOR_APP_UPDATE` set to `false` stops Syft from asking the internet for a newer version. The Syft container mounts the volume read-only, because it only reads the files.

Apply it:

```sh
kubectl apply -f job-sbom-probe.yaml
```

Then check the result. The Job controller creates the pod, and the node pulls the Syft image the first time, so the wait can take a minute:

```sh
kubectl -n starfleet wait --for=condition=Complete job/sbom-probe --timeout=180s
```

The command prints `job.batch/sbom-probe condition met` when the `syft` container has exited with code 0.

## Read the SBOM and compare it with the pod

Syft wrote the document to its standard output, and the kubelet kept that output as the container log. Save the log as a file:

```sh
kubectl -n starfleet logs job/sbom-probe -c syft > probe.cdx.json
```

A CycloneDX document names the tool that made it under `metadata.tools.components`. This is the field that tells a reviewer which Syft version produced the list:

```sh
jq -r '.metadata.tools.components[] | "\(.name) \(.version)"' probe.cdx.json
```

The command prints `syft 1.57.0`, the version of the pinned image. Next, count the Alpine packages in the SBOM and the packages in the Alpine package database of the running pod. Each Alpine package in a CycloneDX document has a package URL (purl) that starts with `pkg:apk/`. In the file `/lib/apk/db/installed`, each package starts with a line that begins with `P:`:

```sh
jq '[.components[] | select(.purl // "" | startswith("pkg:apk/"))] | length' probe.cdx.json
kubectl -n starfleet exec deploy/probe -- grep -c '^P:' /lib/apk/db/installed
```

The two numbers are equal. Syft read the same package database that the running container holds, so the SBOM lists every Alpine package of the image. Last, check that the init container ran the same content as the `probe` container. The kubelet records the image ID of an init container under `initContainerStatuses`:

```sh
kubectl -n starfleet get pod -l job-name=sbom-probe -o jsonpath='{.items[0].status.initContainerStatuses[0].imageID}{"\n"}'
```

The value is the same image ID that the first command printed for the `probe` pod. That match is the evidence that the SBOM describes the content that runs, not only an image with the same name.

You can now make an SBOM inside the cluster from a pinned Syft image, read the tool version from the document, and tie the document to a running image by its image ID. The open question is how long the SBOM stays true: it describes the image at scan time, so a new image ID needs a new SBOM.

## Common pitfalls

> [!WARNING]
> - **Scanning the tag instead of the running content.** A moving tag can point to new content after the pod started. Compare the image ID of the init container with the image ID of the running pod.
> - **Leaving out `--quiet`.** Syft then writes progress lines, and the saved log is not valid JSON.
> - **Copying too little of the root file system.** Syft finds Alpine packages through `/lib/apk/db/installed`. Without `/lib` the SBOM has no Alpine packages.
> - **Using an unpinned Syft image.** A different Syft version can find different packages. Pin the image tag and read the version from `metadata.tools.components`.
