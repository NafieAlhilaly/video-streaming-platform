# AWS Elemental MediaLive — ABR transcoding (LL-HLS)
#
# Receives a single-bitrate feed from MediaConnect and encodes it into an ABR
# ladder (1080p / 720p / 480p) using H.264 + AAC.  The resulting HLS (MPEG-TS)
# segments are pushed via HTTP PUT to MediaPackage v2, which repackages them
# into CMAF/LL-HLS on egress.
#
# Encoding parameters:
#   Codec:            H.264 (AVC)                Audio: AAC-LC 128 kbps
#   GOP:              1 second (closed)          Framerate: 30 fps
#   Segment duration: 2 seconds                  Channel class: SINGLE_PIPELINE

resource "aws_medialive_input" "main" {
  depends_on = [awscc_iam_role.medialive]

  name     = "${local.name_prefix}-input"
  role_arn = awscc_iam_role.medialive.arn
  type     = "MEDIACONNECT"

  media_connect_flows {
    flow_arn = awscc_mediaconnect_flow.main.flow_arn
  }

  tags = {
    Name = "${local.name_prefix}-input"
  }
}

# NOTE: MediaLive channels are now created dynamically by the Lambda orchestrator.
# The aws_medialive_channel.main resource has been removed.
# Lambda will create channels with the same encoding parameters at runtime.
# See lambda.tf and eventbridge.tf for details.
