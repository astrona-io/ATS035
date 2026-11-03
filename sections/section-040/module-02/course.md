---
draft: true
exam_objectives:
- Perform static analysis of user workloads and container images (e.g. Kubesec, KubeLinter)
---
# Scan Images And Configuration With Trivy

A scanner turns a large artifact into a short list of findings. Trivy is an open-source scanner from Aqua Security that reads container images, file system folders and configuration files, and compares what it finds with databases of known vulnerabilities and with built-in misconfiguration rules. The scanner is only useful when a team decides, in advance, which findings stop a release and which do not.

This module teaches what each Trivy command scans, how severity filters, the unfixed filter and exit codes turn a report into a pipeline gate, and how to record an exception that expires. It also states what a finding does and does not prove.

## Learning objectives

After this module you can:

- Choose between `trivy image`, `trivy fs` and `trivy config` for a given artifact and say what each one reads.
- Limit a report with `--severity` and `--ignore-unfixed`, and make a command fail with `--exit-code`.
- Record a time-limited exception in an ignore file and explain why it must have an owner and an end date.
- Explain how the age of the vulnerability database changes a result, and what a finding proves and does not prove.
- Compute a gate decision from a scan report in JSON.

## Before you start

You need a terminal with `kubectl` and `python3`. The Trivy commands run on your own machine, so install Trivy before the parts that use it. Scans that need the network download the vulnerability database the first time. The cluster commands read a saved scan report from the playground cluster, so you can practise the gate rules without a network scan.

| Namespace | What is in it |
| --- | --- |
| `starfleet` | The `probe` Deployment, the `shuttle` pod, a ConfigMap `scan-results` with a scan report in Trivy JSON shape, and a ConfigMap `scan-exceptions` with an ignore list |
| `outpost` | The `drifter` client pod |

The report in `scan-results` is test data with made-up identifiers that start with `FIXTURE`. It is not a real scan of any image.

## Reading order

1. What Trivy scans: images, folders and configuration
2. Severity filters, unfixed findings and exit codes
3. Exceptions, database freshness and what a finding proves
4. Summary

Launch your playground now, and keep it running next to you while you read:

<!-- astrona:playground -->
