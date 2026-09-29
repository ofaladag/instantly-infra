terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
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
