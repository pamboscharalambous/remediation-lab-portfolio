variable "project_id" {
  description = "GCP project ID to deploy into. Use a throwaway/demo project, never production."
  type        = string
}

variable "region" {
  description = "GCP region for regional resources."
  type        = string
  default     = "us-central1"
}

variable "admin_cidr" {
  description = "CIDR block allowed HTTPS access to the VPC (e.g. your home/office IP or VPN egress). Replace the default before applying — it is a placeholder, not a safe value."
  type        = string
  default     = "203.0.113.0/24" # TEST-NET-3, RFC 5737 — documentation-only range, replace this
}

variable "authorized_invoker_email" {
  description = "Email of the specific Google account or group allowed to invoke the Cloud Run service. Replaces the allUsers binding from the vulnerable baseline."
  type        = string
}
