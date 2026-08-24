# vulnerable-baseline

This is the **"before" state** of the remediation lab: a small GCP environment
with four deliberate misconfigurations, each modeled on a pattern that shows
up repeatedly in real incident response engagements.

This branch exists to be scanned, reported on, and then fixed in
`hardened-remediated` — it is not meant to represent good practice.

## Findings

| # | Resource | Finding | Real-world pattern it represents |
|---|----------|---------|-----------------------------------|
| 1 | `google_project_iam_member.app_sa_owner` | Service account granted `roles/owner` | App/CI service account over-scoped at setup, never tightened |
| 2 | `google_storage_bucket_iam_member.public_read` | Bucket readable by `allUsers` | Legacy ACLs left on from a rushed migration |
| 3 | `google_cloud_run_v2_service_iam_member.public_invoke` | Cloud Run allows unauthenticated invocation | `--allow-unauthenticated` used for testing, never reverted |
| 4 | `google_compute_firewall.allow_all_ingress` | Firewall allows all ports from `0.0.0.0/0` | "Temporary" debug rule never removed |

## Running it

```powershell
terraform init
terraform plan -var="project_id=YOUR_DEMO_PROJECT_ID"
terraform apply -var="project_id=YOUR_DEMO_PROJECT_ID"
```

Use a disposable demo project. Nothing here should ever touch production.

## Tearing it down

```powershell
terraform destroy -var="project_id=YOUR_DEMO_PROJECT_ID"
```

Destroy it after each demo session — that's what keeps this at $0 most of
the month. Cloud Run and Storage scale to zero when idle, but the firewall
and IAM bindings cost nothing to leave misconfigured, so don't let that
lull you into leaving the project running.

## Next step

Run the Trivy/Checkov CI gate from `terraform-security-gate.yml` against
this branch first — it should fail on all four findings above. That failed
run, plus the fixed re-run against `hardened-remediated`, is your before/after
evidence for the remediation plan.
