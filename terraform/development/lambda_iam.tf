# IAM role for AWS Lambda MediaLive channel orchestrator
#
# The Lambda function needs permissions to:
# - Create, describe, delete, start, and stop MediaLive channels
# - Read/write channel metadata to DynamoDB
# - Write operational logs to CloudWatch
# - Assume the existing MediaLive role (for channel creation)

data "aws_iam_policy_document" "lambda_orchestrator_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "lambda_orchestrator_permissions" {
  # CloudWatch Logs — for Lambda execution logs
  statement {
    sid = "CloudWatchLogs"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }

  # MediaLive — create, manage, and delete channels
  statement {
    sid = "MediaLiveChannelManagement"

    actions = [
      "medialive:CreateChannel",
      "medialive:CreateTags",
      "medialive:DeleteChannel",
      "medialive:DescribeChannel",
      "medialive:ListChannels",
      "medialive:StartChannel",
      "medialive:StopChannel",
      "medialive:UpdateChannel",
    ]

    resources = ["*"]
  }

  # DynamoDB — track active channels in registry table
  statement {
    sid = "DynamoDBChannelRegistry"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DeleteItem",
    ]

    resources = [aws_dynamodb_table.medialive_channels.arn]
  }

  # DynamoDB — read/write channel configuration templates
  statement {
    sid = "DynamoDBConfigRegistry"

    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DeleteItem",
    ]

    resources = [aws_dynamodb_table.medialive_config_registry.arn]
  }

  # DynamoDB Streams — process TTL expiration events for channel cleanup
  statement {
    sid = "DynamoDBStreams"

    actions = [
      "dynamodb:DescribeStream",
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:ListStreams",
    ]

    resources = [aws_dynamodb_table.medialive_channels.stream_arn]
  }

  # IAM — pass the existing MediaLive role to new channels
  statement {
    sid = "PassMediaLiveRole"

    actions = [
      "iam:PassRole",
    ]

    resources = [awscc_iam_role.medialive.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["medialive.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_orchestrator" {
  name               = "${local.name_prefix}-lambda-orchestrator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_orchestrator_assume_role.json

  tags = {
    Name        = "${local.name_prefix}-lambda-orchestrator-role"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy" "lambda_orchestrator" {
  name   = "${local.name_prefix}-lambda-orchestrator-policy"
  role   = aws_iam_role.lambda_orchestrator.id
  policy = data.aws_iam_policy_document.lambda_orchestrator_permissions.json
}

# Role for EventBridge Scheduler to invoke the Creator Lambda
resource "aws_iam_role" "scheduler_invocation_role" {
  name = "${local.name_prefix}-scheduler-invocation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invocation_policy" {
  name = "${local.name_prefix}-scheduler-invocation-policy"
  role = aws_iam_role.scheduler_invocation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Effect   = "Allow"
      Resource = [aws_lambda_function.medialive_creator.arn]
    }]
  })
}
