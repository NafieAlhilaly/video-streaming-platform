# DynamoDB table for tracking MediaLive channels managed by Lambda
#
# This table serves as the source of truth for active MediaLive channels
# created by the Lambda orchestrator. Each channel creates a record with
# its lifecycle state, creation time, and metadata.

resource "aws_dynamodb_table" "medialive_channels" {
  name         = "${local.name_prefix}-medialive-channels"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "channel_id"

  attribute {
    name = "channel_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # Global Secondary Index for querying channels by status
  global_secondary_index {
    name            = "status-created-index"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "OLD_IMAGE"

  # Enable TTL for automatic cleanup of deleted channels
  ttl {
    attribute_name = "deletion_scheduled_at"
    enabled        = true
  }

  tags = {
    Name        = "${local.name_prefix}-medialive-channels"
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
  }
}
