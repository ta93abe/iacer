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


resource "aws_s3_bucket" "contents" {
  bucket = "iacer-contents"
}


resource "aws_s3_bucket" "media" {
  bucket = "iacer-media"
}

resource "aws_iam_policy" "console_access" {
  name        = "iacer-console-access"
  description = "Allow console access"

  policy = <<EOF
    {
        "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "console:*"
      ],
      "Resource": "*"
    }
  ]
    }
  EOF
}


resource "aws_iam_user" "console_user" {
  name = "iacer-console-user"
  path = "/"
}

resource "aws_iam_user_policy_attachment" "console_access" {
  user       = aws_iam_user.console_user.name
  policy_arn = aws_iam_policy.console_access.arn
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/main.zip"
}


resource "aws_lambda_function" "backup" {
  function_name    = "main"
  handler          = "main.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda.output_path)
  role             = aws_iam_role.iam_for_lambda.arn
}
