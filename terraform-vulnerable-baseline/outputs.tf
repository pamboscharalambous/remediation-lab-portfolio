output "bucket_name" {
  value = google_storage_bucket.app_bucket.name
}

output "cloud_run_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "service_account_email" {
  value = google_service_account.app_sa.email
}
