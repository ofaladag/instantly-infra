terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "3.33.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.60"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}
# Credentials come only from HCLOUD_TOKEN and CLOUDFLARE_API_TOKEN.
provider "hcloud" {}
provider "cloudflare" {}

# Hetzner S3 credentials come from MINIO_USER / MINIO_PASSWORD, not HCLOUD_TOKEN.
provider "minio" {
  minio_server        = "nbg1.your-objectstorage.com"
  minio_region        = "nbg1"
  minio_ssl           = true
  skip_bucket_tagging = true
}
