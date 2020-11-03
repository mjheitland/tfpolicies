#--- Providers

terraform {
  required_version = "~> 0.13"
  required_providers {
    aws = ">= 3.12.0"
  }
  # backend "s3" {
  #   key = "tfsnapshot.tfstate"
  # }
}

provider "aws" {
  region = "eu-west-1"
  profile = "account2"
}

data "aws_caller_identity" "current" {}


#--- Assemble IAM policies

data "aws_iam_policy_document" "iam_policy_document_a" {
    # Allows reading from all buckets
    statement {
        sid = "1"
        actions = ["s3:GetObject"]
        resources = ["arn:aws:s3:::*"]
    }

    # Allow put object in "some-bucket"
    statement {
        sid = "2"
        actions = ["s3:PutObject"]
        resources = ["arn:aws:s3:::some-bucket/*"]
    }
}

data "aws_iam_policy_document" "iam_policy_document_b" {
    source_json = data.aws_iam_policy_document.iam_policy_document_a.json

    # Allows reading from a specific bucket
    statement {
        sid = "1"
        actions = ["s3:GetObject"]
        resources = ["arn:aws:s3:::some-bucket/*"]
    }

    # Allows put object in "a-different-bucket"
    statement {
        sid = "3"
        actions = ["s3:PutObject"]
        resources = ["arn:aws:s3:::a-different-bucket/*"]
    }
}

resource "aws_iam_policy" "iam_policy" {
  name   = "tfpolicies_iam_policy"
  policy = data.aws_iam_policy_document.iam_policy_document_b.json
}

resource "aws_iam_role" "iam_role" {
    name = "tfpolicies_iam_role"
    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "iam_policy_attachment" {
  name       = "tfpolicies_iam_policy_attachment"
  roles      = [aws_iam_role.iam_role.name]
  #groups     = [aws_iam_group.group.name]
  #users      = [aws_iam_user.user.name]
  policy_arn = aws_iam_policy.iam_policy.arn
}


#--- Organizational Units

data "aws_organizations_organization" "org" {}

data "aws_organizations_organizational_units" "ou_0" {
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "my_ou_1" {
  name      = "my_ou_1"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "my_ou_2" {
  name      = "my_ou_2"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}


#--- SCP

data "aws_iam_policy_document" "my_scp_1" {
    statement {
        sid = "myscp1"
        effect = "Deny"
        actions = ["*"]
        resources = ["arn:aws:s3:::my-bucket/*"]
    }
}

data "aws_iam_policy_document" "my_scp_2" {
    statement {
        sid = "myscp2"
        effect = "Deny"
        actions = ["*"]
        resources = ["arn:aws:s3:::another-bucket/*"]
    }
}

module "aggregated_policy_1" {
    source = "git::https://github.com/cloudposse/terraform-aws-iam-policy-document-aggregator.git?ref=master"

    source_documents = [
      data.aws_iam_policy_document.my_scp_1.json
    ]
}

module "aggregated_policy_1_2" {
    source = "git::https://github.com/cloudposse/terraform-aws-iam-policy-document-aggregator.git?ref=master"

    source_documents = [
      data.aws_iam_policy_document.my_scp_1.json,
      data.aws_iam_policy_document.my_scp_2.json
    ]
}

resource "aws_organizations_policy" "my_scp_1" {
  name        = "tfpolicies_my_scp_1"
  description = "My SCP 1"
  content     = module.aggregated_policy_1.result_document 
}

resource "aws_organizations_policy" "my_scp_1_2" {
  name        = "tfpolicies_my_scp_1_2"
  description = "My SCP 1 2"
  content     = module.aggregated_policy_1_2.result_document 
}

resource "aws_organizations_policy_attachment" "account_policy_attachment_account" {
  policy_id = aws_organizations_policy.my_scp_1.id
  target_id = data.aws_caller_identity.current.account_id
}

resource "aws_organizations_policy_attachment" "ou_policy_attachment_1" {
  policy_id = aws_organizations_policy.my_scp_1.id
  target_id = aws_organizations_organizational_unit.my_ou_1.id 
}

resource "aws_organizations_policy_attachment" "ou_policy_attachment_1_2" {
  policy_id = aws_organizations_policy.my_scp_1_2.id
  target_id = aws_organizations_organizational_unit.my_ou_2.id 
}


#--- Outputs

output "account_ids" {
  value = data.aws_organizations_organization.org.accounts[*].id
}

output "ou_0" {
    value = data.aws_organizations_organizational_units.ou_0
}

output "my_ou_1_id" {
    value = aws_organizations_organizational_unit.my_ou_1.id
}

output "my_ou_2_id" {
    value = aws_organizations_organizational_unit.my_ou_2.id
}

output "my_scp_1_id" {
    value = aws_organizations_policy.my_scp_1.id
}

output "my_scp_1_2_id" {
    value = aws_organizations_policy.my_scp_1_2.id
}