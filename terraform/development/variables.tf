variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "live-stream"
}

variable "srt_port" {
  description = "SRT listener port for MediaConnect ingest"
  type        = number
  default     = 5000
}

variable "srt_latency" {
  description = "SRT minimum latency in milliseconds (retransmission buffer)"
  type        = number
  default     = 500
}

variable "srt_source_cidr" {
  description = "CIDR block allowed to send SRT to MediaConnect"
  type        = string
  default     = "0.0.0.0/0"
}
