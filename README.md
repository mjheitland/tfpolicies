# Mini project to demonstrate aggregation of multiple policies into one

This technique can be helpful as there is a limit of max 5 SCPs per account and per organisation unit

Here the aggregated policy is used within an
- IAM role
- SCP 

Creates 
+ 1 aws_iam_policy (combining multiple aws_iam_policy_documents into one policy)
+ 1 aws_iam_role.iam_role
+ 1 aws_iam_policy_attachment (linking policy and role)
+ 2 aws_organizations_organizational_unit
+ 2 aws_organizations_policy
+ 1 aws_organizations_policy_attachment (attaches SCP to account)
+ 2 aws_organizations_policy_attachment (attaches SCP to organization unit)

## Links
[Merging and Overriding IAM Policies in Terraform](https://blog.quigley.codes/merging-iam-in-terraform/) 

[Quotas for AWS Organizations](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html)