variable "aws_region" {
  description = "Region used for the AWS API calls. AWS Organizations is global, but a region is still required by the provider."
  type        = string
  default     = "us-east-1"
}

variable "create_organization" {
  description = "true = create the AWS organization in this account (this account becomes the management account). false = use an existing organization."
  type        = bool
  default     = false
}

variable "feature_set" {
  description = "Organization feature set. ALL enables SCPs and all management features; CONSOLIDATED_BILLING only supports billing. Used only when create_organization is true."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "CONSOLIDATED_BILLING"], var.feature_set)
    error_message = "feature_set must be ALL or CONSOLIDATED_BILLING."
  }
}

variable "enabled_policy_types" {
  description = "Policy types to enable on the organization root, e.g. SERVICE_CONTROL_POLICY, TAG_POLICY, BACKUP_POLICY. Used only when create_organization is true."
  type        = list(string)
  default     = ["SERVICE_CONTROL_POLICY"]
}

variable "aws_service_access_principals" {
  description = "AWS service principals to enable trusted access for, e.g. cloudtrail.amazonaws.com, config.amazonaws.com. Used only when create_organization is true."
  type        = list(string)
  default     = []
}

variable "ou_name" {
  description = "Name of the organizational unit to create (e.g. \"Workloads\", \"Sandbox\")."
  type        = string

  validation {
    condition     = length(var.ou_name) >= 1 && length(var.ou_name) <= 128
    error_message = "ou_name must be between 1 and 128 characters."
  }
}

variable "parent_id" {
  description = "ID of the parent OU or root (e.g. \"r-abcd\" or \"ou-abcd-12345678\"). Leave null to create the OU directly under the organization root."
  type        = string
  default     = null

  validation {
    condition     = var.parent_id == null || can(regex("^(r-[0-9a-z]{4,32}|ou-[0-9a-z]{4,32}-[a-z0-9]{8,32})$", var.parent_id))
    error_message = "parent_id must be a root ID (r-xxxx) or an OU ID (ou-xxxx-xxxxxxxx), or null."
  }
}

variable "child_ous" {
  description = "Optional nested OUs to create under the new OU. Each object needs a name; tags are optional."
  type = list(object({
    name = string
    tags = optional(map(string), {})
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to the OU(s)."
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Tags applied to every resource through the provider default_tags block."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
  }
}

variable "attach_region_restriction_scp" {
  description = "Whether to create and attach a Service Control Policy that denies actions outside allowed_regions."
  type        = bool
  default     = false
}

variable "allowed_regions" {
  description = "Regions that member accounts in this OU may use when attach_region_restriction_scp is true."
  type        = list(string)
  default     = ["us-east-1"]
}

variable "exempt_global_services" {
  description = "Global services whose actions are excluded from the region restriction SCP (they do not have regional endpoints)."
  type        = list(string)
  default = [
    "iam:*",
    "organizations:*",
    "route53:*",
    "cloudfront:*",
    "waf:*",
    "wafv2:*",
    "shield:*",
    "budgets:*",
    "ce:*",
    "support:*",
    "sts:*",
    "health:*",
    "globalaccelerator:*",
  ]
}
