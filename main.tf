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


#--- SCP

data "aws_iam_policy_document" "myscp1" {
    statement {
        sid = "myscp1"
        effect = "Deny"
        actions = ["*"]
        resources = ["arn:aws:s3:::my-bucket/*"]
    }
}

data "aws_iam_policy_document" "myscp2" {
    statement {
        sid = "myscp2"
        effect = "Deny"
        actions = ["*"]
        resources = ["arn:aws:s3:::another-bucket/*"]
    }
}

 module "aggregated_policy" {
    source = "git::https://github.com/cloudposse/terraform-aws-iam-policy-document-aggregator.git?ref=master"

    source_documents = [
      data.aws_iam_policy_document.myscp1.json,
      data.aws_iam_policy_document.myscp2.json
    ]
}

resource "aws_organizations_policy" "myscp" {
  name        = "tfpolicies_ou_scp"
  description = "My SCP"
  content     = module.aggregated_policy.result_document 
# alternative 1: 
#   content = data.aws_iam_policy_document.myscp2.json
# alternative 2:
#   content = <<CONTENT
# {
#   "Version": "2012-10-17",
#   "Statement": {
#     "Effect": "Allow",
#     "Action": "*",
#     "Resource": "*"
#   }
# }
# CONTENT  
}

data "aws_organizations_organization" "org" {}

data "aws_organizations_organizational_units" "ou_0" {
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "my_ou" {
  name      = "my_ou"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_policy_attachment" "account_policy_attachment" {
  policy_id = aws_organizations_policy.myscp.id
  target_id = data.aws_caller_identity.current.account_id
}

resource "aws_organizations_policy_attachment" "ou_policy_attachment" {
  policy_id = aws_organizations_policy.myscp.id
  target_id = aws_organizations_organizational_unit.my_ou.id # attach SCP to my_ou
}


#--- Outputs

output "account_ids" {
  value = data.aws_organizations_organization.org.accounts[*].id
}

output "ou_0" {
    value = data.aws_organizations_organizational_units.ou_0
}

output "my_ou_id" {
    value = aws_organizations_organizational_unit.my_ou.id
}

output "my_scp_id" {
    value = aws_organizations_policy.myscp.id
}