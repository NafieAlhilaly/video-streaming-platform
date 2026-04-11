# AWS EventBridge — MediaLive Channel Orchestrator Trigger
#
resource "aws_scheduler_schedule" "medialive_scheduled_creation" {
  name        = "${local.name_prefix}-scheduled-create"
  group_name  = "default"
  description = "Triggers MediaLive channel creation at a specific datetime"

  # flexible_time_window allows the task to run within a window to avoid thundering herds.
  # For live events, we usually set this to OFF for precision.
  flexible_time_window {
    mode = "OFF"
  }

  # Example: "at(yyyy-mm-ddThh:mm:ss)"
  schedule_expression          = "at(2024-12-31T23:59:59)"
  schedule_expression_timezone = "UTC"

  target {
    arn      = aws_lambda_function.medialive_creator.arn
    role_arn = aws_iam_role.scheduler_invocation_role.arn

    # This payload is passed directly to your lambda_create.py handler
    input = jsonencode({
      config_name  = "1080p-HIGH"
      ttl_hours    = 12
      auto_start   = true
      channel_name = "scheduled-event-stream"
    })
  }
}
