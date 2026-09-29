#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
terraform -chdir="$repo_dir/terraform" fmt -check -recursive
for target in modules/stack environments/stg environments/prod; do
  terraform -chdir="$repo_dir/terraform/$target" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$repo_dir/terraform/$target" validate
  terraform -chdir="$repo_dir/terraform/$target" test
done
