# Remediation Architecture Lab — GCP

A simulated pre-deployment remediation engagement, built to demonstrate the
full lifecycle of an infrastructure security review: baseline assessment,
findings, a hardened fix, and closure evidence — the same workflow this
[Senior Remediation Architect, STS](https://www.google.com/about/careers/applications/jobs/results/134635130693001926-senior-remediation-architect-security-transformation-services-mandiant)
role runs against real client environments.

Everything here is static analysis. **No cloud resources were deployed** —
every finding below comes from `terraform plan` output plus two independent
IaC scanners run against the same code, which is deliberately the cheapest
and safest way to prove this workflow works.

## Structure

```
remediation-lab-portfolio/
├── terraform-vulnerable-baseline/   the "before" environment — 8 intentional findings
├── terraform-hardened-remediated/   the "after" environment — findings closed, 2 accepted
├── evidence/
│   ├── before-report.md             baseline findings, mapped to real-world patterns
│   └── after-report.md              closure evidence + the second-pass patch
└── .github/workflows/
    └── terraform-security-gate.yml  CI gate: Trivy + Checkov, SHA-pinned
```

## The story, in order

1. **[`terraform-vulnerable-baseline/`](./terraform-vulnerable-baseline/)** —
   a small GCP environment (service account, storage bucket, Cloud Run
   service, VPC) with 8 deliberate misconfigurations, each modeled on a
   pattern that shows up repeatedly in real IR engagements rather than
   invented for the demo.
2. **[`evidence/before-report.md`](./evidence/before-report.md)** — those 8
   findings, scanned with Trivy and Checkov independently. The two tools
   agree on most findings but not all — one real issue (an unauthenticated
   Cloud Run endpoint) was caught by neither and only surfaced through
   manual review of the plan output. That gap is the most useful finding
   in the whole report.
3. **[`terraform-hardened-remediated/`](./terraform-hardened-remediated/)** —
   the same environment, every finding fixed, mapped 1:1 back to the
   baseline in its own README.
4. **[`evidence/after-report.md`](./evidence/after-report.md)** — closure
   evidence. Fixing the 8 original findings surfaced 6 smaller residual
   ones on resources that didn't exist in the baseline. 4 were patched;
   2 were accepted and documented with a stated reason rather than forced
   closed (a bucket logging to itself is structurally impossible, and a
   log-only bucket doesn't need customer-managed encryption). The final
   scan confirms exactly those 2 remain — nothing more, nothing missed.
5. **[`.github/workflows/terraform-security-gate.yml`](./.github/workflows/terraform-security-gate.yml)** —
   the same two scanners as a CI gate, with the Trivy action pinned to a
   verified commit SHA rather than a mutable tag, following the March 2026
   trivy-action supply chain incident.

## Reproducing this locally

```powershell
cd terraform-vulnerable-baseline
terraform init
terraform plan -var="project_id=YOUR_DEMO_PROJECT_ID"
trivy config .
checkov -d .
```

Repeat against `terraform-hardened-remediated` (needs two extra variables —
see that folder's README) to reproduce the closure evidence.

## Why this repo is public, and why nothing here costs anything to run

This repo is public on purpose, for two reasons: it's meant to be read by a
hiring manager, and GitHub Actions on standard runners is free and
unmetered on public repositories — the CI gate above costs nothing to run,
no matter how often it runs. Locally, every scan was run directly against
Terraform code with nothing ever deployed, so the entire lab — baseline,
hardened branch, both scanners, both reports — cost $0 to produce.
