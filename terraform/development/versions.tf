terraform {
  required_version = "~> 1.14"

  cloud {
    organization = "nafea"

    workspaces {
      name = "workspace-test"
    }
  }

  required_providers {
    # Primary provider — AWS Cloud Control API
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.71.0"
    }

    # Retained for resources not yet available in the AWSCC provider:
    # MediaLive (channel, input), CloudFront distribution, S3 objects.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
  }
}
