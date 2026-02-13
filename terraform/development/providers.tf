# Primary provider — AWS Cloud Control API
provider "awscc" {
  region = var.aws_region
}

# Retained for resources not yet available in the AWSCC provider:
# aws_medialive_channel, aws_medialive_input, aws_cloudfront_distribution,
# aws_s3_object, and data sources (aws_iam_policy_document).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
