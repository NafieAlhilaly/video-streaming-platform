# DynamoDB Table for MediaLive Channel Configurations
# Stores saved channel configurations with renditions, color space, and correction settings

resource "aws_dynamodb_table" "medialive_config_registry" {
  name         = "${local.name_prefix}-medialive-configs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "config_name"

  attribute {
    name = "config_name"
    type = "S"
  }

  # TTL for old configurations (optional - set to null to disable)
  ttl {
    attribute_name = "deprecation_scheduled_at"
    enabled        = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-medialive-configs"
    }
  )
}

# Output the configuration table name
output "medialive_config_table_name" {
  description = "DynamoDB table for MediaLive channel configuration templates"
  value       = aws_dynamodb_table.medialive_config_registry.name
}

# Output the configuration table ARN
output "medialive_config_table_arn" {
  description = "ARN of the MediaLive configuration table"
  value       = aws_dynamodb_table.medialive_config_registry.arn
}
