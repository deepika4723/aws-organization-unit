output "organization_id" {
  description = "ID of the AWS organization (created or existing)."
  value       = local.organization_id
}

output "root_id" {
  description = "ID of the organization root."
  value       = local.root_id
}

output "ou_id" {
  description = "ID of the created organizational unit (use as parent_id for child OUs or accounts)."
  value       = aws_organizations_organizational_unit.this.id
}

output "ou_arn" {
  description = "ARN of the created organizational unit."
  value       = aws_organizations_organizational_unit.this.arn
}

output "child_ou_ids" {
  description = "Map of child OU name to OU ID."
  value       = { for k, v in aws_organizations_organizational_unit.child : k => v.id }
}

output "region_restriction_policy_id" {
  description = "ID of the region restriction SCP, or null if not created."
  value       = try(aws_organizations_policy.region_restriction[0].id, null)
}
