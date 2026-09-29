# Separate root directories and explicit local paths isolate environment state.
# Migrate to encrypted, locking remote backends before shared production work.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
