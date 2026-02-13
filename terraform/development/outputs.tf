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

output "medialive_channel_id" {
  description = "MediaLive channel ID"
  value       = aws_medialive_channel.main.id
}

output "mediapackage_channel_name" {
  description = "MediaPackage v2 channel name"
  value       = awscc_mediapackagev2_channel.main.channel_name
}
