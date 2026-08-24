terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

# =====================================================================
# HARDENED — every block below is annotated with which finding from
# the evidence report it closes. Compare against terraform-vulnerable-
# baseline/main.tf to see the exact diff.
# =====================================================================

# --- FIX for finding 3: no project-level Owner grant -----------------
# The service account exists, but gets no project-wide role at all.
# Access is scoped per-resource below instead (bucket, KMS key).
resource "google_service_account" "app_sa" {
  account_id   = "hardened-app-sa"
  display_name = "Hardened App Service Account"
}

# --- FIX for finding 7: dedicated bucket to receive access logs ------
resource "google_storage_bucket" "log_bucket" {
  name                        = "${var.project_id}-access-logs"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced" # fixes CKV_GCP_114
  force_destroy                = true

  versioning {
    enabled = true # fixes CKV_GCP_78
  }

  # Deliberately no `logging` block here: a bucket cannot log to itself.
  # CKV_GCP_62 will still flag this bucket specifically — that's expected
  # and documented as an accepted, unsatisfiable finding, not an oversight.
}

# --- FIX for finding 8: customer-managed encryption key ---------------
resource "google_kms_key_ring" "bucket_keyring" {
  name     = "app-bucket-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "bucket_key" {
  name            = "app-bucket-key"
  key_ring        = google_kms_key_ring.bucket_keyring.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true # fixes CKV_GCP_82 — see README before running terraform destroy
  }
}

# GCS needs explicit permission to use the key on your behalf — this
# is easy to forget and Terraform won't warn you; the bucket create
# will just fail at apply time if this binding is missing.
resource "google_kms_crypto_key_iam_member" "gcs_key_user" {
  crypto_key_id = google_kms_crypto_key.bucket_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

# --- FIXES for findings 2, 5, 6, 7, 8 in one resource -----------------
resource "google_storage_bucket" "app_bucket" {
  name                        = "${var.project_id}-app-data"
  location                    = var.region
  uniform_bucket_level_access = true      # fix 5: no legacy per-object ACLs
  public_access_prevention    = "enforced" # fix 2: belt-and-suspenders even without a public IAM binding
  force_destroy                = true

  versioning {
    enabled = true # fix 6
  }

  logging {
    log_bucket = google_storage_bucket.log_bucket.name # fix 7
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket_key.id # fix 8
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_key_user]
}

# Scoped access instead of the allUsers binding removed from baseline —
# this is finding 2's actual fix: no public IAM member exists anywhere.
resource "google_storage_bucket_iam_member" "app_sa_access" {
  bucket = google_storage_bucket.app_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app_sa.email}"
}

# --- FIX for finding 4: no allUsers invoker binding -------------------
resource "google_cloud_run_v2_service" "app" {
  name     = "hardened-app"
  location = var.region

  template {
    service_account = google_service_account.app_sa.email
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "authorized_invoker" {
  name     = google_cloud_run_v2_service.app.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "user:${var.authorized_invoker_email}" # named principal, not allUsers
}

# --- FIX for finding 1: no open firewall ------------------------------
resource "google_compute_network" "vpc" {
  name                    = "hardened-vpc"
  auto_create_subnetworks = false # custom-mode, explicit subnets only
}

resource "google_compute_subnetwork" "app_subnet" {
  name          = "hardened-app-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true # fixes GCP-0075 / CKV_GCP_74

  log_config { # fixes GCP-0029, GCP-0076 / CKV_GCP_26
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata              = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_scoped_https" {
  name    = "allow-scoped-https"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"] # only the one port actually needed, not 0-65535
  }

  source_ranges = [var.admin_cidr] # a real CIDR, not 0.0.0.0/0
}
# No other firewall rules exist — GCP denies by default, so anything
# not explicitly allowed above is closed.
