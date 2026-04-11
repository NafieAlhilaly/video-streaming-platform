output "aws_region" {
  description = "AWS region of the deployment"
  value       = var.aws_region
}

output "cloudfront_stream_domain" {
  description = "CloudFront distribution domain for the live stream"
  value       = aws_cloudfront_distribution.stream.domain_name
}

output "hls_playback_url" {
  description = "Full HLS playback URL via CloudFront CDN"
  value       = local.hls_playback_url
}

output "mediaconnect_flow_arn" {
  description = "MediaConnect flow ARN — use to look up SRT ingest IP"
  value       = awscc_mediaconnect_flow.main.flow_arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for MediaLive channel registry"
  value       = aws_dynamodb_table.medialive_channels.name
}

output "dynamodb_config_table_name" {
  description = "DynamoDB table name for MediaLive channel configurations"
  value       = aws_dynamodb_table.medialive_config_registry.name
}

output "dynamodb_config_table_arn" {
  description = "ARN of the MediaLive configuration table"
  value       = aws_dynamodb_table.medialive_config_registry.arn
}

output "lambda_creator_arn" {
  description = "ARN of the MediaLive creator Lambda function"
  value       = aws_lambda_function.medialive_creator.arn
}

output "lambda_deleter_arn" {
  description = "ARN of the MediaLive deleter Lambda function"
  value       = aws_lambda_function.medialive_deleter.arn
}

output "lambda_orchestrator_role_arn" {
  description = "IAM role ARN for Lambda orchestrator"
  value       = aws_iam_role.lambda_orchestrator.arn
}

output "mediapackage_channel_name" {
  description = "MediaPackage v2 channel name"
  value       = awscc_mediapackagev2_channel.main.channel_name
}
