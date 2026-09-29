# Application objects, separate from database backups and Terraform state.
resource "minio_s3_bucket" "application" {
  bucket         = var.application_bucket_name
  acl            = "private"
  force_destroy  = false
  object_locking = false
  lifecycle { prevent_destroy = true }
}

output "application_object_storage" {
  value = {
    bucket   = minio_s3_bucket.application.bucket
    endpoint = "https://nbg1.your-objectstorage.com"
    region   = "nbg1"
    access   = "private"
  }
}
