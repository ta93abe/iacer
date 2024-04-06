terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.44.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

locals {
  iacer_hostname = "app.terraform.io"
}

data "tls_certificate" "iacer_certificate" {
  url = "https://${local.iacer_hostname}"
}

resource "aws_iam_openid_connect_provider" "iacer_provider" {
  url             = data.tls_certificate.iacer_certificate.url
  client_id_list  = ["aws.workload.identity"]
  thumbprint_list = [data.tls_certificate.iacer_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "iacer_role" {
  name = "iacer-role"

  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": "${aws_iam_openid_connect_provider.iacer_provider.arn}"
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "${local.iacer_hostname}:aud": "${one(aws_iam_openid_connect_provider.iacer_provider.client_id_list)}"
                    },
                    "StringLike": {
                        "${local.iacer_hostname}:sub": "organization:${var.iacer_organization_name}:project:*:workspace:*:run_phase:*"
                    }
                }
            }
        ]
    }
    EOF
}

resource "aws_iam_policy" "iacer_policy" {
  name        = "iacer-policy"
  description = "TFC run policy"

  policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:*",
                    "lambda:*",
                    "apigateway:*",
                    "cloudwatch:*",
                    "events:*",
                    "iam:*"
                ],
                "Resource": "*"
            }
        ]
    }
EOF
}

resource "aws_iam_role_policy_attachment" "iacer_policy_attachment" {
  role       = aws_iam_role.iacer_role.name
  policy_arn = aws_iam_policy.iacer_policy.arn
}
