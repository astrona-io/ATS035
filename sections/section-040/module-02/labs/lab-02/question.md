---
draft: true
---
# Scan An Image And Bind The Release Decision

Solve this question on: `terminal`

The independent VM contains `alpine:3.18.0`, deliberately old training input, Trivy and a database downloaded at bootstrap. `/srv/scan` has no submitted evidence yet.

Allow about 15 minutes for the tasks.

## Tasks

1. Run a vulnerability scan of the supplied Docker image using `/var/cache/trivy-training`, no database update and offline scanning. Save complete Trivy JSON to `/srv/scan/report.json`.
2. Save `/srv/scan/decision.json` with exactly `image_id`, `database_updated_at`, integer `high_critical`, and `decision`. Count every HIGH or CRITICAL finding across all targets. Block when that count is nonzero; otherwise allow. Use the image ID from the scan and `UpdatedAt` from the database metadata.

## Constraints

Do not change the cached image, scanner or database. Do not filter fixed or unfixed vulnerabilities. Keep the complete report. The database must be at most 72 hours old; recreate an older lab before working.

## How the answer is checked

The grader runs Trivy again against the current image with the same verified database snapshot. It compares target identities and every vulnerability tuple, then recomputes the count and decision. Results vary as the downloaded database changes; no fixed count is required.
