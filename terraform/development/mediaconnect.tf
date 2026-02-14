# AWS Elemental MediaConnect — SRT ingest
#
# Operates in SRT *listener* mode: the flow opens a port and waits for an
# incoming SRT stream (e.g. from OBS Studio or FFmpeg).
# Latency is left at the SRT default (120 ms) which suits contribution feeds.

resource "awscc_mediaconnect_flow" "main" {
  name = "${local.name_prefix}-flow"

  source = {
    description    = "Public SRT ingest source"
    ingest_port    = var.srt_port
    min_latency    = var.srt_latency
    name           = "phone-stream-source"
    protocol       = "srt-listener"
    whitelist_cidr = var.srt_source_cidr
  }

  source_monitoring_config = {
    thumbnail_state = "ENABLED"
  }
}
