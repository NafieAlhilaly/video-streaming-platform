# IAM role for AWS Elemental MediaLive.
# MediaLive needs permissions to pull from MediaConnect, push HLS to
# MediaPackage v2, and write operational logs to CloudWatch.

data "aws_iam_policy_document" "medialive_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["medialive.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "medialive_permissions" {
  # CloudWatch Logs
  statement {
    sid = "CloudWatchLogs"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }

  # MediaConnect — managed by MediaLive
  statement {
    sid = "MediaConnect"

    actions = [
      "mediaconnect:AddFlowOutputs",
      "mediaconnect:ManagedAddOutput",
      "mediaconnect:ManagedDescribeFlow",
      "mediaconnect:ManagedRemoveOutput",
    ]

    resources = ["*"]
  }

  # MediaPackage v2 — push HLS segments
  statement {
    sid = "MediaPackageV2"

    actions = [
      "mediapackagev2:PutObject",
    ]

    resources = ["*"]
  }
}

resource "awscc_iam_role" "medialive" {
  assume_role_policy_document = data.aws_iam_policy_document.medialive_assume_role.json
  role_name                   = "${local.name_prefix}-medialive-role"

  policies = [{
    policy_document = data.aws_iam_policy_document.medialive_permissions.json
    policy_name     = "${local.name_prefix}-medialive-policy"
  }]

  tags = local.common_tags_list
}
