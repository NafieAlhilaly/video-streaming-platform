# Live Video Streaming Platform

AWS-based live video streaming platform with SRT ingest, ABR transcoding, LL-HLS packaging, and CDN distribution — fully provisioned with Terraform.

## Architecture

![](./charts/stream_flow.png)

| Component | AWS Service | Purpose |
|-----------|-------------|---------|
| Ingest | Elemental MediaConnect | SRT listener — receives live stream from the internet |
| Transcoding | Elemental MediaLive | ABR encoding (1080p / 720p / 480p) with H.264 + AAC |
| Packaging | Elemental MediaPackage v2 | LL-HLS manifest & CMAF segment generation |
| Distribution | Amazon CloudFront | Low-latency edge CDN delivery |
| Player | Static Website | hls.js-based HTML5 video player |

## Signal Ingest (SRT)

| Setting | Value |
|---------|-------|
| Protocol | SRT (Secure Reliable Transport) |
| Mode | Listener — MediaConnect opens a port and waits for the sender |
| Port | 5000 (configurable via `srt_port`) |
| Latency | 500 ms (configurable via `srt_latency`) |

**Source options:** OBS Studio

## Transcoding — ABR Ladder

| Rendition | Resolution | Video Bitrate | Codec | Profile | GOP | Audio |
|-----------|-----------|---------------|-------|---------|-----|-------|
| 1080p | 1920×1080 | 5 Mbps | H.264 | High | 1 s | AAC 128 kbps |
| 720p | 1280×720 | 3 Mbps | H.264 | Main | 1 s | AAC 128 kbps |
| 480p | 854×480 | 1.5 Mbps | H.264 | Main | 1 s | AAC 128 kbps |

- **Frame rate:** 30 fps
- **GOP structure:** Closed GOP, 1-second duration (30 frames)
- **Segment duration:** 2 seconds

## Packaging (LL-HLS)

| Setting | Value |
|---------|-------|
| Protocol | LL-HLS (Low-Latency HTTP Live Streaming) |
| Container | CMAF (fMP4) |
| Segment duration | 2 seconds |
| Manifest | Multi-variant LL-HLS playlist with partial segments |

### Why HLS over DASH?

| | HLS | DASH |
|---|---|---|
| Container | MPEG-TS (.ts) or fMP4 | fMP4 (.m4s) |
| Manifest | `.m3u8` (text) | `.mpd` (XML) |
| iOS / Safari | Native | Not supported |
| Android / Chrome | Via hls.js or native | Native |
| Latency | ~6–30 s (LL-HLS ~2–5 s) | ~3–15 s (LL-DASH ~2–5 s) |
| AWS support | MediaPackage v2 native | MediaPackage v2 native |

This project uses **HLS** for broadest device compatibility — it works natively on iOS/Safari and is supported everywhere else via [hls.js](https://github.com/video-dev/hls.js/).

## CDN Distribution (CloudFront)

| Setting | Value |
|---------|-------|
| Cache TTL | min 0 s · default 1 s · max 8 s |
| Protocol | HTTPS (HTTP → HTTPS redirect) |

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-2` | AWS deployment region |
| `project_name` | `live-stream` | Resource naming prefix |
| `environment` | `dev` | Environment tag |
| `srt_port` | `5000` | SRT listener port |
| `srt_latency` | `500` | SRT minimum latency in ms |
| `srt_source_cidr` | `0.0.0.0/0` | Allowed SRT sender CIDR |

Override defaults with a `terraform.tfvars` file or `-var` flags:

```bash
terraform -chdir=terraform/development apply -var="srt_port=6000"
```


## Web Player

Minimal HTML5 page using [hls.js](https://github.com/video-dev/hls.js/) for adaptive HLS playback.

## Streaming with OBS Studio

### Prerequisites

- [OBS Studio](https://obsproject.com/) installed
- Infrastructure deployed (`terraform apply` completed)
- MediaConnect flow started:
  ```bash
  aws mediaconnect start-flow --flow-arn <FLOW_ARN> --region us-east-2
  ```
- MediaLive channel started:
  ```bash
  aws medialive start-channel --channel-id <CHANNEL_ID> --region us-east-2
  ```

### OBS Configuration

1. Open OBS → **Settings** → **Stream**
2. Set **Service** to `Custom...`
3. Set **Server** to the SRT URL (replace `<INGEST_IP>` with the MediaConnect ingest IP from `terraform output`):
   ```
   srt://<INGEST_IP>:5000?mode=caller&latency=200000
   ```
   > `latency` is in **microseconds** — `200000` = 200 ms (must match or exceed your `srt_latency` variable)
4. Leave **Stream Key** empty

### Recommended OBS Output Settings

Go to **Settings** → **Output** → **Output Mode: Advanced** → **Streaming** tab:

| Setting | Value |
|---------|-------|
| Encoder | x264 or hardware (NVENC/QSV) |
| Rate Control | CBR |
| Bitrate | 5000–6000 kbps |
| Keyframe Interval | 1 s |
| Profile | High |
| Tune | zerolatency |

Go to **Settings** → **Video**:

| Setting | Value |
|---------|-------|
| Base Resolution | 1920×1080 |
| Output Resolution | 1920×1080 |
| FPS | 30 |

### Start Streaming

1. Click **Start Streaming** in OBS
2. Verify the MediaConnect source shows **Active** in the AWS console
3. Open `web/index.html` in a browser and paste the CloudFront HLS URL:
   ```
   https://<CLOUDFRONT_DOMAIN>/out/v1/<GROUP>/<CHANNEL>/<ENDPOINT>/index.m3u8
   ```
   The full URL is available via `terraform output hls_playback_url`.
