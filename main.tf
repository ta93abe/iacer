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

data "aws_iam_policy_document" "api_gateway_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "iam_policy_AmazonAPIGatewayPushToCloudWatchLogs" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

data "aws_iam_policy" "iam_policy_AWSLambdaRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

resource "aws_iam_role_policy_attachment" "api_gateway_policy_logs" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = data.aws_iam_policy.iam_policy_AmazonAPIGatewayPushToCloudWatchLogs.policy
}

resource "aws_iam_role_policy_attachment" "api_gateway_policy_lambda" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = data.aws_iam_policy.iam_policy_AWSLambdaRole.policy
}


resource "aws_iam_role" "api_gateway_role" {
  name               = "api_gateway_role"
  assume_role_policy = data.aws_iam_policy_document.api_gateway_assume_role.json
}

resource "aws_api_gateway_rest_api" "api" {
  name = "iacer-api"
  body = jsonencode({
    openapi = "3.0.1",
    info = {
      title   = "IACER API"
      version = "1.0"
    },
    paths = {
      "/path1" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "POST" # LambdaへのアクセスはPOSTでないといけないらしい
            payloadFormatVersion = "1.0"
            type                 = "AWS_PROXY"
            uri                  = aws_lambda_function.backup.invoke_arn
            credentials          = aws_iam_role.api_gateway_role.arn
          }
        }
      }
    }
  })
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on  = [aws_api_gateway_rest_api.api]
  stage_name  = "prod"
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.api))
  }
}


data "aws_iam_policy_document" "api_gateway_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["execute-api:Invoke"]
    resources = ["${aws_api_gateway_rest_api.api.execution_arn}/*"]
  }
}

resource "aws_api_gateway_rest_api_policy" "policy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  policy      = data.aws_iam_policy_document.api_gateway_policy.json
}
