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


resource "aws_cloudwatch_event_rule" "eventbridge_rule" {
  name        = "eventbridge_rule"
  description = "EventBridge Rule"

  # Run every hour
  schedule_expression = "cron(0 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "eventbridge_target" {
  rule = aws_cloudwatch_event_rule.eventbridge_rule.name
  arn  = aws_lambda_function.backup.arn
}

data "aws_iam_policy_document" "eventbridge_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eventbridge_service_role" {
  name               = "eventbridge_service_role"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_policy.json
}
