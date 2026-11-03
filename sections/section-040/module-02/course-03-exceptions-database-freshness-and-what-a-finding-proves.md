---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Exceptions, Database Freshness And What A Finding Proves

Some blocking findings cannot be fixed this week: the fixed package is not released for the base image, or the vulnerable code path is not used. A team then needs an exception. An exception without an owner and an end date is a permanent hole in the gate. This part shows how Trivy records an exception, why the same scan can change without any change to the image, and what a finding does and does not prove.

## Ignore files

Trivy reads an ignore file named `.trivyignore` in the current folder, or the file named by `--ignorefile`. In the plain format each line is a finding identifier, and a line can end with `exp:` and a date after which the exception stops working. Comments start with `#`:

```text
# Accepted by the platform team until the next base image rebuild.
CVE-2025-00000 exp:2026-12-31
```

<!-- astrona:playground:renew -->

The YAML format, usually named `.trivyignore.yaml`, adds a reason and a limit to one path. Save this as `.trivyignore.yaml`:

```yaml
vulnerabilities:
  - id: CVE-2025-00000
    statement: The vulnerable function is not called. Owner: platform team.
    expired_at: 2026-12-31
```

The identifier above is an example, not a real finding. After the `expired_at` date, Trivy reports the finding again, so the gate fails again and forces a new decision. That behaviour is the reason to always set a date.

## The database changes the result

The vulnerability database is downloaded from a registry and updated regularly. A scan compares package versions with the database that is on the machine at scan time. An image that was clean last month can show a new CRITICAL finding today, without any change to the image. The reverse also happens, when a severity is lowered.

Show the version of Trivy and the date of its database:

```sh
trivy version
```

The output includes the database version and the time it was last updated. A pipeline that scans offline, for example with `--skip-db-update`, uses whatever database is already cached. Record the Trivy version, the database update time and the image digest next to every result, so that a later reader can tell why two scans differ.

## Apply the ignore list to the saved report

Select the playground cluster and read the ignore list that belongs to the saved report:

```sh
export KUBECONFIG="$(astrona kubeconfig ats-035-playground-040-02)"
test "$(kubectl config current-context)" = "kind-astro-ats-035-playground-040-02" || exit 1
kubectl -n starfleet get configmap scan-exceptions -o jsonpath='{.data.trivyignore\.txt}'
```

The list holds one identifier, `FIXTURE-0005`, with a comment that names who accepted it. In the saved report, `FIXTURE-0005` is HIGH and has a fixed version, so without the exception it would block the release. With the exception it is **waived**, which means it is listed in the decision as accepted and does not block.

A complete gate decision therefore has four lists. The blocking findings stop the release. The waived findings have an exception. The unfixed findings have no fix yet. Findings below the severity threshold are not listed. For the saved report, two findings block (`FIXTURE-0001` and `FIXTURE-0002`), one is waived (`FIXTURE-0005`) and one is unfixed (`FIXTURE-0003`), so the decision is `fail`. The task in this module asks you to record exactly this decision.

## What a finding proves

A vulnerability finding proves that an installed package version appears in the database as affected. It does not prove that the flaw can be reached in your workload, that an attacker can use it, or that the severity fits your environment. A missing finding proves only that the database has no entry for what the scanner could identify. A binary copied into the image without a package record, or a package the scanner cannot read, may produce no finding.

For this reason a scan is evidence for a decision and not the decision itself. The decision joins the scan with the workload settings, the admission rules and the exception list.

## Common pitfalls

> [!WARNING]
> - **Exceptions without a date or an owner.** They never expire and nobody remembers why they exist.
> - **Comparing two scans without the database date.** A different result may come from a newer database and not from a changed image.
> - **Reading "no findings" as "no vulnerabilities".** It means "no known findings in what the scanner could read".
> - **Ignoring a finding because the code path seems unused.** Write the reason down so that a reviewer can check it.
