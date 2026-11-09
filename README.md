# AWS Organizational Unit (Terraform)

Creates an AWS Organizations OU with optional nested OUs, tags, and an optional
region-restriction Service Control Policy (SCP).

## Files

| File | Purpose |
| --- | --- |
| `versions.tf` | Terraform and AWS provider version constraints |
| `providers.tf` | AWS provider and default tags |
| `variables.tf` | Input variables with validation |
| `main.tf` | Organization lookup, OU(s), SCP and attachment |
| `outputs.tf` | OU IDs/ARNs, root ID, policy ID |
| `terraform.tfvars.example` | Sample values |

## Prerequisites

1. **The organization.** Set `create_organization = true` to have Terraform create it, or `false` (default) if one already exists.
   - Creating an organization makes the account you run as the **management account**. The account must not already belong to an organization, or the apply fails with `AlreadyInOrganizationException`.
   - Creation is protected by `prevent_destroy`. To tear it down you must first remove every member account, then delete the `aws_organizations_organization` block and apply again.
2. **Run from the management account.** Member accounts cannot create OUs. Use credentials or an assumed role for the management account.
3. **Permissions** for the executing identity:
   - `organizations:CreateOrganization`, `organizations:EnableAWSServiceAccess`, `organizations:EnablePolicyType`, `organizations:DeleteOrganization` (only if you ever destroy it)
   - `organizations:DescribeOrganization`, `organizations:ListRoots`
   - `organizations:CreateOrganizationalUnit`, `UpdateOrganizationalUnit`, `DeleteOrganizationalUnit`, `DescribeOrganizationalUnit`, `ListOrganizationalUnitsForParent`
   - `organizations:CreatePolicy`, `UpdatePolicy`, `DeletePolicy`, `DescribePolicy`, `AttachPolicy`, `DetachPolicy`, `ListPoliciesForTarget`
   - `organizations:TagResource`, `UntagResource`, `ListTagsForResource`
4. **SCPs (optional):** the `SERVICE_CONTROL_POLICY` policy type must be enabled on the root. It is enabled by default with the `ALL` feature set.
5. **Terraform** `>= 1.5.0`, AWS provider `~> 5.0`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Use the outputs in other modules, for example `ou_id` as the `parent_id` for account creation.

## Notes

- **Deleting an OU** fails if it still contains accounts or child OUs. Move the accounts out first.
- **Region SCP:** before attaching it, confirm that no workload in the target OU uses a region outside `allowed_regions`. A Deny SCP applies immediately to every member account in the OU. SCPs never restrict the management account itself.
- **Global services** such as IAM, Route 53, and CloudFront are excluded from the region SCP through `exempt_global_services`. Review this list for your workloads.
- **`FullAWSAccess`** remains attached to the root. Removing it would deny everything unless another allow SCP is attached, so leave it alone.
- Do not attach the region SCP to the root without a plan review. It affects every account in the organization.
- Terraform state holds the organization and OU IDs. Store state remotely (for example S3 with DynamoDB or S3 native locking).
