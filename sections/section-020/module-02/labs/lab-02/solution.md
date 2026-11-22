---
exam_objectives:
- Understand your supply chain (e.g. SBOM, CI/CD, artifact repositories)
---
# Bind An SBOM And A VEX Statement To An Image Digest Solution

Use a host shell with the private kubeconfig for this lab's kind cluster. A kubeconfig identifies the cluster and credentials used by kubectl, the Kubernetes command-line tool.

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-lab-020-02-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-lab-020-02-02" || exit 1
```

Keep this connection selected. Every command in this lab works on this cluster only.

## Inspect the records

Both stored records name the tag `python:3.13-alpine`. A tag can move to other content, so neither record says which image it describes. Read them first:

```sh
kubectl -n starfleet-035-020-02-02 get configmap sbom-record scan-finding -o yaml
```

The `subject` of `sbom-record` and the `image` of `scan-finding` are both the tag. The fix is to bind the records to the identity that the cluster runs.

## Read the image identity

The kubelet writes the `imageID` of each container into the pod status. It is the identity of the content that the container runtime (containerd) started. Read it for the container `probe` in each `probe` pod:

```sh
kubectl -n starfleet-035-020-02-02 get pod -l app=probe -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].imageID}{"\n"}{end}'
```

Both pods show the same `imageID`, because they start from one image. Keep the value in a shell variable, and cut the digest after the last `@` with the shell expansion `${image_id##*@}`:

```sh
image_id="$(kubectl -n starfleet-035-020-02-02 get pod -l app=probe -o jsonpath='{.items[0].status.containerStatuses[0].imageID}')"
echo "$image_id"
echo "${image_id##*@}"
```

The second line starts with `sha256:`. If the `imageID` has no `@`, the node loaded the image from an archive, and the whole value is the identity that you record.

## Bind the SBOM record to the image

Save this as `configmap-sbom-record.yaml`, with `<IMAGE_ID>` replaced by the output of `echo "$image_id"` and `<IMAGE_DIGEST>` replaced by the output of `echo "${image_id##*@}"`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sbom-record
  namespace: starfleet-035-020-02-02
data:
  format: CycloneDX
  scope: alpine-installed-packages
  subject: "<IMAGE_ID>"
  imageDigest: "<IMAGE_DIGEST>"
```

Apply it:

```sh
kubectl apply -f configmap-sbom-record.yaml
```

## Record the VEX statement

A VEX (Vulnerability Exploitability eXchange) statement is a claim about one vulnerability in one product. Here the product is the image digest. The status `not_affected` needs a justification, and the claim needs an author and a review date, like any exception.

Save this as `configmap-vex-statement.yaml`, with `<IMAGE_DIGEST>` replaced by the same digest:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vex-statement
  namespace: starfleet-035-020-02-02
data:
  vulnerability: TRAINING-2026-0001
  product: "<IMAGE_DIGEST>"
  status: not_affected
  justification: vulnerable_code_not_in_execute_path
  author: fleet-security-team
  reviewBy: "2027-05-31"
```

Apply it:

```sh
kubectl apply -f configmap-vex-statement.yaml
```

Then check the result:

```sh
kubectl -n starfleet-035-020-02-02 get configmap sbom-record vex-statement -o yaml
```

The `subject` of `sbom-record` is now the full `imageID`, and `imageDigest` and the `product` of `vex-statement` are the same `sha256:` value. The VEX statement applies to this content only. If the `probe` Deployment later runs a new image, its digest changes, and the statement must be reviewed again.

After recording your result, remove the lab with `astrona destroy ats-035-lab-020-02-02`.

## Common pitfalls

> [!WARNING]
> - **Keeping the tag as the subject.** The tag `python:3.13-alpine` can point to other content tomorrow. The record must name the digest.
> - **Cutting at the first `@` or the first `:`.** The digest is the part after the last `@`, and it keeps its `sha256:` prefix.
> - **Writing `not_affected` without a reason.** A VEX status without a justification, an author and a review date is an exception that nobody can check.
