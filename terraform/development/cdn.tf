# Amazon CloudFront — CDN distribution for the LL-HLS live stream
#
# Fronts the MediaPackage v2 origin endpoint with aggressive TTLs optimised for
# low-latency HLS (default 1 s, max 8 s).  Viewers hit CloudFront edge
# locations instead of the origin directly.

resource "aws_cloudfront_distribution" "stream" {
  comment         = "CDN for ${var.project_name} live stream"
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"

  origin {
    domain_name = awscc_mediapackagev2_channel_group.main.egress_domain
    origin_id   = "mediapackage"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = "mediapackage"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers = [
        "Access-Control-Request-Headers",
        "Access-Control-Request-Method",
        "Origin",
      ]
      query_string = true

      cookies {
        forward = "none"
      }
    }

    # Aggressive TTLs — LL-HLS requires very short caching for partial segments
    default_ttl = 1
    max_ttl     = 8
    min_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${local.name_prefix}-cdn"
  }
}
