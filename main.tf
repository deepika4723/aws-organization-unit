# ---------------------------------------------------------------------------
# Organization: either create it here, or look up an existing one.
# ---------------------------------------------------------------------------
resource "aws_organizations_organization" "this" {
  count = var.create_organization ? 1 : 0

  feature_set                   = var.feature_set
  enabled_policy_types          = var.enabled_policy_types
  aws_service_access_principals = var.aws_service_access_principals

  lifecycle {
    # Deleting an organization is disruptive. Remove this block first if you
    # really intend to destroy it.
    prevent_destroy = true
  }
}

data "aws_organizations_organization" "existing" {
  count = var.create_organization ? 0 : 1
}

locals {
  organization_id = var.create_organization ? aws_organizations_organization.this[0].id : data.aws_organizations_organization.existing[0].id
  root_id         = var.create_organization ? aws_organizations_organization.this[0].roots[0].id : data.aws_organizations_organization.existing[0].roots[0].id

  # Default to the organization root when no parent is given.
  parent_id = coalesce(var.parent_id, local.root_id)

  # Region restriction SCP. Denies every action outside allowed_regions,
  # except global services listed in exempt_global_services.
  region_restriction_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyAllOutsideAllowedRegions"
        Effect    = "Deny"
        NotAction = var.exempt_global_services
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.allowed_regions
          }
        }
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Organizational Unit
# ---------------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "this" {
  name      = var.ou_name
  parent_id = local.parent_id
  tags      = var.tags
}

# Optional nested OUs
resource "aws_organizations_organizational_unit" "child" {
  for_each = { for ou in var.child_ous : ou.name => ou }

  name      = each.value.name
  parent_id = aws_organizations_organizational_unit.this.id
  tags      = merge(var.tags, each.value.tags)
}

# ---------------------------------------------------------------------------
# Service Control Policy (optional)
# SCPs need the SERVICE_CONTROL_POLICY policy type enabled on the
# organization root. It is enabled by default for organizations created
# with the "ALL" feature set.
# ---------------------------------------------------------------------------
resource "aws_organizations_policy" "region_restriction" {
  count = var.attach_region_restriction_scp ? 1 : 0

  name        = "${var.ou_name}-region-restriction"
  description = "Denies actions outside approved regions for ${var.ou_name}."
  type        = "SERVICE_CONTROL_POLICY"
  content     = local.region_restriction_policy
  tags        = var.tags
}

resource "aws_organizations_policy_attachment" "region_restriction" {
  count = var.attach_region_restriction_scp ? 1 : 0

  policy_id = aws_organizations_policy.region_restriction[0].id
  target_id = aws_organizations_organizational_unit.this.id
}
