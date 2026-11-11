---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Summary

Trivy scans three kinds of input. The `image` command reads the packages and dependencies inside a container image, the `fs` command reads a folder such as a source repository, and the `config` command reads configuration files for misconfigurations. The vulnerability, secret and misconfiguration scanners answer different questions, so a clean result from one says nothing about the others.

A report becomes a gate through three rules. The severity filter keeps the findings that matter, the unfixed filter removes findings that a team cannot fix by updating a package, and the exit code makes the pipeline step fail. The default exit code is zero, so a scan fails a step only when `--exit-code` is set.

An exception belongs in an ignore file with a reason, an owner and an end date. After the date, the finding returns and the gate fails again. A complete gate decision lists the blocking, waived and unfixed findings and the threshold used.

A scan compares package versions with the vulnerability database on the machine at scan time. The same image can give different results on different days, so the Trivy version, the database date and the image digest belong next to every result. A finding proves that a package version is listed as affected. It does not prove that the flaw can be reached, and a missing finding does not prove that the image is free of vulnerabilities.

- Scan the digest that will run, with the image, the folder and the configuration.
- Set `--severity`, `--ignore-unfixed` and `--exit-code` on purpose.
- Give every exception an owner and an end date.
- Record the scanner version and the database date with the result.



## Independent live assessment

Prepare with [Use A Fresh Scan As Release Evidence](course-03a-run-and-check-a-fresh-scan.md). [Scan An Image And Bind The Release Decision](labs/lab-02/question.md) uses its own qemu environment. The report matches a fresh scan of the supplied image with the lab database; The decision records the current image, database timestamp and complete high/critical count.

<!-- astrona:playground:destroy -->
