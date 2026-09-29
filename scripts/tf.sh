#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
if [[ $# -lt 2 ]]; then
  echo "Usage: scripts/tf.sh stg|prod <terraform command> [args...]" >&2
  exit 2
fi
environment=$1
shift
case "$environment" in stg|prod) ;; *) echo "Environment must be stg or prod." >&2; exit 2 ;; esac
env_dir="$repo_dir/terraform/environments/$environment"
if [[ ! -f "$env_dir/.env" ]]; then
  echo "Create $env_dir/.env from .env.example and fill in that environment's tokens." >&2
  exit 1
fi
# Never reuse tokens inherited from another environment's terminal session.
unset HCLOUD_TOKEN CLOUDFLARE_API_TOKEN MINIO_USER MINIO_PASSWORD MINIO_ACCESS_KEY MINIO_SECRET_KEY MINIO_SESSION_TOKEN
source "$env_dir/.env"
: "${HCLOUD_TOKEN:?Fill HCLOUD_TOKEN in the selected environment .env file}"
: "${CLOUDFLARE_API_TOKEN:?Fill CLOUDFLARE_API_TOKEN in the selected environment .env file}"
if [[ "$environment" == stg ]]; then
  : "${MINIO_USER:?Fill MINIO_USER with the staging S3 Access Key}"
  : "${MINIO_PASSWORD:?Fill MINIO_PASSWORD with the staging S3 Secret Key}"
  export MINIO_USER MINIO_PASSWORD
fi
export HCLOUD_TOKEN CLOUDFLARE_API_TOKEN
exec terraform -chdir="$env_dir" "$@"
