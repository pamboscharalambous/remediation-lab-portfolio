output "bucket_name" {
  value = google_storage_bucket.app_bucket.name
}

output "log_bucket_name" {
  value = google_storage_bucket.log_bucket.name
}

output "cloud_run_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "service_account_email" {
  value = google_service_account.app_sa.email
}

output "kms_key_id" {
  value = google_kms_crypto_key.bucket_key.id
}
