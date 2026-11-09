# Must be run with credentials for the AWS ORGANIZATIONS MANAGEMENT account.
# Only the management account can create OUs and attach policies.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}
