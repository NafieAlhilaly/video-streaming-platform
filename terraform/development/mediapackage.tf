# AWS Elemental MediaPackage v2 — LL-HLS packaging
#
# Receives fMP4 segments from MediaLive and serves them to viewers through an
# origin endpoint.  The origin endpoint generates LL-HLS (Low-Latency HLS)
# manifests with 2-second CMAF segments and partial segments for sub-second
# chunk delivery.

resource "awscc_mediapackagev2_channel_group" "main" {
  channel_group_name = "${local.name_prefix}-group"
  description        = "Channel group for ${var.project_name}"

  tags = local.common_tags_list
}

resource "awscc_mediapackagev2_channel" "main" {
  channel_group_name = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name       = "${local.name_prefix}-channel"
  description        = "Packaging channel for ${var.project_name}"

  tags = local.common_tags_list
}

resource "awscc_mediapackagev2_origin_endpoint" "hls" {
  channel_group_name   = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name         = awscc_mediapackagev2_channel.main.channel_name
  container_type       = "CMAF"
  description          = "LL-HLS origin endpoint"
  origin_endpoint_name = "${local.name_prefix}-hls"

  low_latency_hls_manifests = [{
    manifest_name                      = "index"
    program_date_time_interval_seconds = 1
  }]

  segment = {
    segment_duration_seconds = local.segment_duration
  }

  tags = local.common_tags_list
}

# Allow CloudFront (and any viewer) to pull from the origin endpoint
resource "awscc_mediapackagev2_origin_endpoint_policy" "hls" {
  channel_group_name   = awscc_mediapackagev2_channel_group.main.channel_group_name
  channel_name         = awscc_mediapackagev2_channel.main.channel_name
  origin_endpoint_name = awscc_mediapackagev2_origin_endpoint.hls.origin_endpoint_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "mediapackagev2:GetObject"
      Resource  = awscc_mediapackagev2_origin_endpoint.hls.arn
    }]
  })
}
