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

# =====================================================================
# VULNERABLE BASELINE — intentionally misconfigured for a remediation
# demo. Each block below is annotated with the finding it represents.
# Do not deploy this to anything but a disposable demo project.
# =====================================================================

# --- FINDING 1: service account granted project Owner ---------------
# Real-world equivalent: an app or CI service account over-scoped
# during initial setup and never tightened. Violates least privilege.
resource "google_service_account" "app_sa" {
  account_id   = "vulnerable-app-sa"
  display_name = "Vulnerable App Service Account"
}

resource "google_project_iam_member" "app_sa_owner" {
  project = var.project_id
  role    = "roles/owner" # FINDING: full project Owner, not scoped roles
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# --- FINDING 2: storage bucket world-readable ------------------------
# Real-world equivalent: a bucket set to legacy ACLs during a rushed
# migration, then never locked down to uniform bucket-level access.
resource "google_storage_bucket" "app_bucket" {
  name                        = "${var.project_id}-app-data"
  location                    = var.region
  uniform_bucket_level_access = false # FINDING: allows legacy per-object ACLs
  force_destroy                = true
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.app_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers" # FINDING: public read access to every object
}

# --- FINDING 3: Cloud Run service open to the internet ---------------
# Real-world equivalent: a service deployed with --allow-unauthenticated
# for quick testing that was never switched back to authenticated-only.
resource "google_cloud_run_v2_service" "app" {
  name     = "vulnerable-app"
  location = var.region

  template {
    service_account = google_service_account.app_sa.email # runs as the over-privileged SA above
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_invoke" {
  name     = google_cloud_run_v2_service.app.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers" # FINDING: unauthenticated invocation allowed
}

# --- FINDING 4: firewall allows all inbound traffic -------------------
# Real-world equivalent: a "temporary" debugging rule that was never
# removed after troubleshooting finished.
resource "google_compute_network" "vpc" {
  name                    = "vulnerable-vpc"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "allow_all_ingress" {
  name    = "allow-all-ingress"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"] # FINDING: every TCP port open
  }

  source_ranges = ["0.0.0.0/0"] # FINDING: open to any source on the internet
}
