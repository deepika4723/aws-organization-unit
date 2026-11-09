# AWS Organizational Unit (Terraform)

Creates an AWS Organizations OU with optional nested OUs, tags, and an optional
region-restriction Service Control Policy (SCP).

## Files

| File | Purpose |
| --- | --- |
| `versions.tf` | Terraform and AWS provider version constraints |
| `backend.tf` | Remote state backend (S3), values supplied at init |
| `.github/workflows/terraform-ou.yml` | CI/CD: validate, plan on PR, apply on `main` |
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
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="key=ou/workloads.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"
terraform plan -out=tfplan
terraform apply tfplan
```

Use the outputs in other modules, for example `ou_id` as the `parent_id` for account creation.

## CI/CD

The workflow `.github/workflows/terraform-ou.yml` runs as follows:

- **Pull request to `main`:** `fmt -check`, `validate`, then `plan`. The plan appears in the job summary. Nothing is changed.
- **Merge to `main`:** `validate`, then `apply` in the `production` environment. The apply job waits for approval.

Authentication uses GitHub OIDC, so no long-lived AWS keys are stored.

### One-time setup

1. **State bucket.** Create an S3 bucket with versioning and default encryption enabled, and block public access. Locking uses S3 native locking (`use_lockfile`), so no DynamoDB table is needed. This requires Terraform `>= 1.10`.
2. **Migrate state.** If the OU was already created from a local machine, copy the local state to the bucket with `terraform init -migrate-state` and the backend settings above. Otherwise, with `create_organization = true`, the next apply will try to create the organization again and fail.
3. **OIDC provider.** In IAM, add the `token.actions.githubusercontent.com` identity provider (audience `sts.amazonaws.com`) to the management account.
4. **Two roles** trusted by that provider, scoped to this repository:
   - `terraform-ou-plan`: read-only Organizations and S3 state access. Trust `sub` = `repo:deepika4723/aws-organization-unit:pull_request`.
   - `terraform-ou-apply`: the permissions listed under *Prerequisites*, plus state access. Trust `sub` = `repo:deepika4723/aws-organization-unit:environment:production`.
5. **GitHub repository variables** (Settings > Secrets and variables > Actions > Variables): `AWS_REGION`, `TF_STATE_BUCKET`, `TF_STATE_KEY`, `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`.
6. **GitHub secret** `TF_VARS`: the full contents of your `terraform.tfvars`. The file is git-ignored, so CI reads it from this secret.
7. **Environment protection.** Settings > Environments > create `production` and add required reviewers. Without this, merges to `main` apply immediately.
8. **Branch protection.** Require the `validate` and `plan` checks on `main`, and require pull requests.

### Notes

- The apply job re-runs `plan` after approval and applies that plan. Review the plan in the pull request before merging.
- Pull requests from forks do not receive secrets, so their plans will fail. This is expected.

## Notes

- **Deleting an OU** fails if it still contains accounts or child OUs. Move the accounts out first.
- **Region SCP:** before attaching it, confirm that no workload in the target OU uses a region outside `allowed_regions`. A Deny SCP applies immediately to every member account in the OU. SCPs never restrict the management account itself.
- **Global services** such as IAM, Route 53, and CloudFront are excluded from the region SCP through `exempt_global_services`. Review this list for your workloads.
- **`FullAWSAccess`** remains attached to the root. Removing it would deny everything unless another allow SCP is attached, so leave it alone.
- Do not attach the region SCP to the root without a plan review. It affects every account in the organization.
- Terraform state holds the organization and OU IDs. Store state remotely (for example S3 with DynamoDB or S3 native locking).
