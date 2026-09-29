# Root inputs; keep aligned with the shared stack module.
variable "project" {
  description = "Resource name prefix."
  type        = string
  default     = "instantly"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project))
    error_message = "Use 2–31 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "location" {
  description = "Both servers and the data volume must share this Hetzner location."
  type        = string
  default     = "fsn1"
}
variable "network_zone" {
  description = "Must match location."
  type        = string
  default     = "eu-central"
}
variable "app_server_type" {
  description = "Available x86 Hetzner server type for APP-01; confirm regional availability."
  type        = string
  default     = "cx23"
}
variable "data_server_type" {
  description = "Available x86 Hetzner server type for DATA-01."
  type        = string
  default     = "cx23"
}
variable "ssh_public_keys" {
  description = "Named administrator PUBLIC SSH keys. Never supply private keys."
  type        = map(string)
  validation {
    condition     = length(var.ssh_public_keys) > 0 && alltrue([for k in values(var.ssh_public_keys) : can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+) [A-Za-z0-9+/=]+", k))])
    error_message = "Provide at least one valid OpenSSH public key."
  }
}
variable "coolify_ssh_public_key" {
  description = "Dedicated Coolify PUBLIC SSH key installed on DATA-01; matching private key stays in Coolify."
  type        = string
  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+) [A-Za-z0-9+/=]+", var.coolify_ssh_public_key))
    error_message = "Supply a public OpenSSH key for Coolify."
  }
}
variable "admin_ipv4_cidrs" {
  description = "Trusted public IPv4 CIDRs allowed to SSH to APP-01. No world-open SSH."
  type        = set(string)
  validation {
    condition     = length(var.admin_ipv4_cidrs) > 0 && alltrue([for c in var.admin_ipv4_cidrs : can(cidrnetmask(c)) && try(tonumber(split("/", c)[1]) >= 24, false)])
    error_message = "Supply IPv4 CIDRs with /24 or narrower masks, preferably individual /32s."
  }
}
variable "domain" {
  description = "Existing Cloudflare authoritative zone domain; GoDaddy remains registrar."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.domain))
    error_message = "Supply a lowercase domain, without scheme, slash or trailing dot."
  }
}
variable "cloudflare_zone_id" {
  description = "Existing Cloudflare zone ID. This repo does not create a second zone."
  type        = string
  validation {
    condition     = can(regex("^[a-f0-9]{32}$", var.cloudflare_zone_id))
    error_message = "Cloudflare zone ID must be 32 lowercase hexadecimal characters."
  }
}
variable "public_app_subdomains" {
  description = "Application A record labels. vpn is reserved and always DNS-only."
  type        = set(string)
  default     = ["api"]
  validation {
    condition     = alltrue([for s in var.public_app_subdomains : can(regex("^[a-z0-9][a-z0-9-]*$", s)) && s != "vpn"])
    error_message = "Use simple DNS labels other than vpn."
  }
}
variable "data_volume_size_gb" {
  description = "Unused in staging (root disk). Module compatibility input for volume size."
  type        = number
  default     = 50
  validation {
    condition     = var.data_volume_size_gb >= 10 && var.data_volume_size_gb <= 10240 && floor(var.data_volume_size_gb) == var.data_volume_size_gb
    error_message = "Volume must be an integer between 10 and 10240 GB."
  }
}
variable "server_backups" {
  description = "Enable server disk backups (attached volumes are NOT included)."
  type        = bool
  default     = true
}
variable "install_coolify" {
  description = "Run the official Coolify installer on initial APP-01 boot. Runtime services remain manual in Coolify."
  type        = bool
  default     = false
}
