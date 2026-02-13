locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
  }

  # AWSCC resources require tags as a list of {key, value} objects.
  common_tags_list = [for k, v in local.common_tags : { key = k, value = v }]

  # ABR ladder — defines encoding renditions for adaptive bitrate streaming
  abr_renditions = {
    "1080p" = {
      bitrate = 5000000
      height  = 1080
      profile = "HIGH"
      width   = 1920
    }
    "720p" = {
      bitrate = 3000000
      height  = 720
      profile = "MAIN"
      width   = 1280
    }
    "480p" = {
      bitrate = 1500000
      height  = 480
      profile = "MAIN"
      width   = 854
    }
  }

  # Encoding parameters
  audio_bitrate         = 128000
  framerate_denominator = 1
  framerate_numerator   = 30
  gop_size_seconds      = 2
  segment_duration      = 6

  # CloudFront playback URL — replaces the MediaPackage egress domain with the
  # CloudFront distribution domain so viewers hit the CDN instead of the origin.
  hls_playback_url = replace(
    awscc_mediapackagev2_origin_endpoint.hls.hls_manifest_urls[0],
    awscc_mediapackagev2_channel_group.main.egress_domain,
    aws_cloudfront_distribution.stream.domain_name
  )
}
