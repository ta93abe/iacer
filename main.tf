terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.45.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}


data "aws_iam_policy_document" "console_json" {
  statement {
    actions   = ["iam:*"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "console_access" {
  name        = "iacer-console-access"
  description = "Allow console access"

  policy = data.aws_iam_policy_document.console_json.json
}


resource "aws_iam_user" "console_user" {
  name = "iacer-console-user"
  path = "/"
}

resource "aws_iam_user_policy_attachment" "console_access" {
  user       = aws_iam_user.console_user.name
  policy_arn = aws_iam_policy.console_access.arn
}
