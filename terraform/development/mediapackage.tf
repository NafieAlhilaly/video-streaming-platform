# AWS Elemental MediaPackage v2 — HLS packaging
#
# Receives HLS segments from MediaLive and serves them to viewers through an
# origin endpoint.  The origin endpoint generates multi-variant HLS manifests
# with 6-second MPEG-TS segments.

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
  container_type       = "TS"
  description          = "HLS origin endpoint"
  origin_endpoint_name = "${local.name_prefix}-hls"

  hls_manifests = [{
    manifest_name = "index"
  }]

  segment = {
    segment_duration_seconds = local.segment_duration
  }

  tags = local.common_tags_list
}
