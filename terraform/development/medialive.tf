# AWS Elemental MediaLive — ABR transcoding
#
# Receives a single-bitrate feed from MediaConnect and encodes it into an ABR
# ladder (1080p / 720p / 480p) using H.264 + AAC.  The resulting HLS segments
# are pushed via HTTP PUT to the MediaPackage v2 ingest endpoint.
#
# Encoding parameters:
#   Codec:            H.264 (AVC)                Audio: AAC-LC 128 kbps
#   GOP:              2 seconds (closed)         Framerate: 30 fps
#   Segment duration: 6 seconds                  Channel class: SINGLE_PIPELINE

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

resource "aws_medialive_channel" "main" {
  depends_on = [awscc_iam_role.medialive]

  channel_class = "SINGLE_PIPELINE"
  name          = "${local.name_prefix}-channel"
  role_arn      = awscc_iam_role.medialive.arn

  input_attachments {
    input_attachment_name = "main-input"
    input_id              = aws_medialive_input.main.id

    input_settings {
      source_end_behavior = "CONTINUE"
    }
  }

  input_specification {
    codec            = "AVC"
    input_resolution = "HD"
    maximum_bitrate  = "MAX_20_MBPS"
  }

  # HLS destination — MediaPackage v2 ingest endpoint
  destinations {
    id = "hls-destination"

    settings {
      url = awscc_mediapackagev2_channel.main.ingest_endpoints[0].url
    }
  }

  encoder_settings {
    timecode_config {
      source = "EMBEDDED"
    }

    # --- Audio ----------------------------------------------------------
    audio_descriptions {
      audio_selector_name = "default"
      name                = "audio_1"

      codec_settings {
        aac_settings {
          bitrate           = local.audio_bitrate
          coding_mode       = "CODING_MODE_2_0"
          rate_control_mode = "CBR"
          sample_rate       = 48000
        }
      }
    }

    # --- Video (one description per ABR rendition) ----------------------
    dynamic "video_descriptions" {
      for_each = local.abr_renditions

      content {
        height = video_descriptions.value.height
        name   = "video_${video_descriptions.key}"
        width  = video_descriptions.value.width

        codec_settings {
          h264_settings {
            bitrate               = video_descriptions.value.bitrate
            framerate_control     = "SPECIFIED"
            framerate_denominator = local.framerate_denominator
            framerate_numerator   = local.framerate_numerator
            gop_size              = local.gop_size_seconds
            gop_size_units        = "SECONDS"
            level                 = "H264_LEVEL_AUTO"
            profile               = video_descriptions.value.profile
            rate_control_mode     = "CBR"
          }
        }
      }
    }

    # --- HLS output group → MediaPackage v2 ----------------------------
    output_groups {
      name = "hls-mediapackage"

      output_group_settings {
        hls_group_settings {
          destination {
            destination_ref_id = "hls-destination"
          }

          hls_cdn_settings {
            hls_basic_put_settings {
              num_retries = 3
            }
          }

          index_n_segments = 10
          segment_length   = local.segment_duration
        }
      }

      # One output per ABR rendition
      dynamic "outputs" {
        for_each = local.abr_renditions

        content {
          audio_description_names = ["audio_1"]
          output_name             = outputs.key
          video_description_name  = "video_${outputs.key}"

          output_settings {
            hls_output_settings {
              name_modifier = "_${outputs.key}"

              hls_settings {
                standard_hls_settings {
                  m3u8_settings {}
                }
              }
            }
          }
        }
      }
    }
  }

  tags = {
    Name = "${local.name_prefix}-channel"
  }
}
