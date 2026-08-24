# hardened-remediated

This is the **"after" state** — the same environment as `terraform-vulnerable-baseline`,
with every finding from the evidence report fixed. Run the same two scanners
against this branch and compare the output directly against the baseline report.

## What changed, mapped to findings

| # | Finding (baseline) | Fix (this branch) |
|---|---|---|
| 1 | Firewall open to `0.0.0.0/0`, all ports | Custom-mode VPC, one rule, one port (443), scoped to `var.admin_cidr` |
| 2 | Bucket publicly readable | No `allUsers` binding anywhere; `public_access_prevention = "enforced"` added as a second layer |
| 3 | Service account granted `roles/owner` | No project-level role at all — access is scoped to the specific bucket via `roles/storage.objectAdmin` |
| 4 | Cloud Run allowed unauthenticated invocation | Invoker role granted to a named `var.authorized_invoker_email`, not `allUsers` |
| 5 | Legacy bucket ACLs | `uniform_bucket_level_access = true` |
| 6 | No bucket versioning | `versioning { enabled = true }` |
| 7 | No bucket access logging | Dedicated `log_bucket` resource, wired via the bucket's `logging` block |
| 8 | No customer-managed encryption | New KMS key ring + key, bucket encrypted with it, GCS service agent granted decrypt/encrypt rights |

## Before you run this

Two variables have no safe default and must be supplied:

```powershell
terraform plan `
  -var="project_id=mandiant-remediation-architect" `
  -var="admin_cidr=YOUR_ACTUAL_IP/32" `
  -var="authorized_invoker_email=you@example.com"
```

- `admin_cidr` defaults to a documentation-only placeholder (`203.0.113.0/24`) that resolves to nothing real — Terraform will accept it, but it isn't a value you should actually deploy with.
- `authorized_invoker_email` has no default on purpose — there's no safe guess for "who should be allowed to call this service."

You'll also need the KMS API enabled, which the baseline project didn't require:

```powershell
gcloud services enable cloudkms.googleapis.com --project=mandiant-remediation-architect
```

## Expected scanner result

Trivy and Checkov should both report at or near zero failures against this
branch. If either still fails on something, that's useful — it either means
this README missed a step, or the scanner is enforcing a stricter standard
than the evidence report scoped for (worth noting in your write-up either
way, not hiding).

## Second-pass patch (residual findings)

After the first scan, four cheap residual findings were closed: subnet flow
logs, subnet Private Google Access, log-bucket versioning, and log-bucket
public access prevention. One more — KMS key deletion protection — was
also closed, but it introduces a real trade-off worth knowing before you
run `terraform destroy`:

**`prevent_destroy = true` on the KMS key will make `terraform destroy`
fail** on that resource. This is the security control working as intended
— it's meant to stop accidental deletion — but it's in direct tension with
this lab's ephemeral, tear-down-after-each-demo design. If you do deploy
this branch and need to destroy it, remove or comment out the `lifecycle`
block on `google_kms_crypto_key.bucket_key`, run `terraform apply` once to
register the change, then `terraform destroy`. Don't work around it with
`terraform state rm` — that orphans the key in GCP without Terraform
knowing, which is a worse outcome than the inconvenience it avoids.

Two findings remain intentionally unresolved and are documented, not
fixed: the log bucket can't log to itself (structurally impossible), and
the log bucket uses Google-managed rather than customer-managed encryption
(accepted — it only holds access logs, lower sensitivity than the app
bucket).

## Cost note

The KMS key ring/key adds a small, genuinely non-zero cost (a few cents a
month per active key version) — the only piece of this whole lab that isn't
effectively free. Still trivial, but worth being able to say precisely
rather than "it's all free" if asked.
