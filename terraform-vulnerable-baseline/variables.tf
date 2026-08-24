variable "project_id" {
  description = "GCP project ID to deploy into. Use a throwaway/demo project, never production."
  type        = string
}

variable "region" {
  description = "GCP region for regional resources."
  type        = string
  default     = "us-central1"
}
