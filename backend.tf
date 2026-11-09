# Remote state in S3 with native locking (requires Terraform >= 1.10).
# The bucket, key and region are passed at init time so no account-specific
# values are committed. See the README for the init command.
terraform {
  backend "s3" {
    encrypt = true
  }
}
