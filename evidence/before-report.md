# Remediation Evidence Report — vulnerable-baseline

**Engagement:** Simulated pre-remediation assessment, GCP project `mandiant-remediation-architect`
**Scope:** Terraform-defined environment — 1 service account, 1 storage bucket, 1 Cloud Run service, 1 VPC with 1 firewall rule
**Method:** Static analysis only. No resources were deployed — findings are drawn from `terraform plan` output plus two independent IaC scanners (Trivy, Checkov) run locally against the same configuration.

---

## Executive Summary

A planned GCP environment was assessed prior to deployment using automated infrastructure-as-code scanning. The assessment identified **8 distinct misconfigurations** spanning identity, storage, and network controls, including one **critical**-severity finding (a firewall rule open to the entire internet on every port) and **three high-severity** findings involving public data exposure and excessive privilege.

Two independent scanners were used deliberately rather than one. They agreed on the storage and network findings but each missed something the other caught, and **neither tool flagged one real issue** — an unauthenticated public entry point on the application service — which was only caught through manual review of the plan output. This is called out explicitly below because it's the most useful finding in this report: automated gates reduce risk, they don't eliminate the need for a human reviewing the actual proposed change.

No cloud resources were provisioned. This is a pre-deployment gate result — catching all of this before `apply` is the point.

---

## Findings

| # | Finding | Severity | Resource | Caught by |
|---|---------|----------|----------|-----------|
| 1 | Firewall allows all inbound traffic, all ports, from `0.0.0.0/0` | **Critical** | `google_compute_firewall.allow_all_ingress` | Trivy (GCP-0027) + Checkov (7 port-specific checks) |
| 2 | Storage bucket readable by anyone on the internet (`allUsers`) | **High** | `google_storage_bucket_iam_member.public_read` | Trivy (GCP-0001) + Checkov (CKV_GCP_28, CKV_GCP_114) |
| 3 | Service account granted project-level `roles/owner` | **High** | `google_project_iam_member.app_sa_owner` | Checkov only (CKV_GCP_117, CKV_GCP_49) |
| 4 | Cloud Run service allows unauthenticated invocation (`allUsers`) | **High** | `google_cloud_run_v2_service_iam_member.public_invoke` | **Neither scanner** — found via manual plan review |
| 5 | Bucket uses legacy per-object ACLs instead of uniform bucket-level access | **Medium** | `google_storage_bucket.app_bucket` | Trivy (GCP-0002) + Checkov (CKV_GCP_29) |
| 6 | Bucket versioning disabled | **Medium** | `google_storage_bucket.app_bucket` | Trivy (GCP-0078) + Checkov (CKV_GCP_78) |
| 7 | Bucket access logging not enabled | **Medium** | `google_storage_bucket.app_bucket` | Checkov only (CKV_GCP_62) |
| 8 | Bucket encryption uses Google-managed key, not customer-managed (CMEK) | **Low** | `google_storage_bucket.app_bucket` | Trivy only (GCP-0066) |

**Tool coverage note:** Checkov ran 18 checks against this configuration (5 passed, 13 failed); Trivy ran 10 checks (0 passed, 10 failed) against the same file. The passed Checkov checks are worth keeping visible too — they show the configuration isn't uniformly bad, which matters for credibility: findings 1–8 above are specific, not a blanket "everything is wrong" result.

**Passed checks (Checkov):** service account not using Admin-privilege shortcuts at the binding level, default service account not used, no Service Account User/Token Creator role granted, firewall doesn't allow *literally* unrestricted all-port access via the specific check Checkov uses for that (superseded in practice by finding #1 above, which a different, more specific check did catch), and the network doesn't rely on GCP's implicit default firewall.

---

## Before → After

This is the **before** state. The `hardened-remediated` branch (next artifact) addresses each finding directly:

| Finding | Planned fix |
|---|---|
| 1. Open firewall | Restrict `source_ranges` to specific CIDR blocks; scope `allow` to only required ports |
| 2. Public bucket | Remove the `allUsers` IAM binding; enable `public_access_prevention = "enforced"` |
| 3. Owner-role service account | Replace `roles/owner` with scoped roles matching actual least-privilege need (e.g. `roles/run.invoker`, `roles/storage.objectAdmin` on the specific bucket only) |
| 4. Public Cloud Run invocation | Remove the `allUsers` invoker binding; require authenticated calls |
| 5. Legacy bucket ACLs | Set `uniform_bucket_level_access = true` |
| 6. No versioning | Add a `versioning { enabled = true }` block |
| 7. No access logging | Configure a logging sink to a dedicated log bucket |
| 8. No CMEK | Add `encryption { default_kms_key_name = ... }` referencing a Cloud KMS key |

---

## Recommendations, Prioritized

1. **Immediate (block deploy):** Fix findings 1–4 before this configuration is ever applied. These represent unauthenticated exposure of data, compute, and identity — the kind of finding that turns into an incident if it reaches production.
2. **Before next review cycle:** Fix findings 5–7. These don't expose anything by themselves but remove safety nets (recovery, auditability) that matter once something does go wrong.
3. **Track, not urgent:** Finding 8 (CMEK). Reasonable to accept Google-managed encryption for a demo/low-sensitivity workload; revisit if this pattern is reused for anything handling regulated data.
4. **Process recommendation, not a code fix:** Finding 4 was invisible to both scanners. For a real engagement, this is the argument for pairing automated IaC scanning with a manual architecture review at the PR stage — not a criticism of either tool, just a documented limitation worth stating plainly to a client rather than implying full coverage.

---

## Appendix: Raw Tool Output

Full `terraform plan`, Trivy, and Checkov output for this run are retained in the project repository at `terraform-vulnerable-baseline/` for verification. Summary counts:

- **terraform plan:** 8 resources to add, 0 to change, 0 to destroy — plan generated successfully, no deployment performed
- **trivy config .:** 10/10 checks failed (0 LOW... actually 2 LOW, 5 MEDIUM, 2 HIGH, 1 CRITICAL)
- **checkov -d .:** 5 passed, 13 failed, 0 skipped
