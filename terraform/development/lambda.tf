resource "aws_cloudwatch_log_group" "lambda_creator" {
  name              = "/aws/lambda/${local.name_prefix}-medialive-creator"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "lambda_deleter" {
  name              = "/aws/lambda/${local.name_prefix}-medialive-deleter"
  retention_in_days = 7
}

resource "aws_lambda_function" "medialive_creator" {
  filename         = data.archive_file.lambda_create.output_path
  function_name    = "${local.name_prefix}-medialive-creator"
  role             = aws_iam_role.lambda_orchestrator.arn
  handler          = "lambda_create.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = data.archive_file.lambda_create.output_base64sha256
  environment {
    variables = {
      DYNAMODB_CONFIG_TABLE_NAME = aws_dynamodb_table.medialive_config_registry.name
      DYNAMODB_TABLE_NAME        = aws_dynamodb_table.medialive_channels.name
      ENVIRONMENT                = var.environment
      MEDIALIVE_INPUT_ID         = aws_medialive_input.main.id
      MEDIALIVE_ROLE_ARN         = awscc_iam_role.medialive.arn
      MEDIAPACKAGE_INGEST_URL    = awscc_mediapackagev2_channel.main.ingest_endpoints[0].url
      PROJECT_NAME               = var.project_name
    }
  }
}

resource "aws_lambda_function" "medialive_deleter" {
  filename         = data.archive_file.lambda_delete.output_path
  function_name    = "${local.name_prefix}-medialive-deleter"
  role             = aws_iam_role.lambda_orchestrator.arn
  handler          = "lambda_delete.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120 # Important: Higher timeout for stop-wait
  source_code_hash = data.archive_file.lambda_delete.output_base64sha256
}

resource "aws_lambda_event_source_mapping" "medialive_cleanup" {
  batch_size       = 1
  event_source_arn = aws_dynamodb_table.medialive_channels.stream_arn
  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["REMOVE"]
      })
    }
  }
  function_name     = aws_lambda_function.medialive_deleter.arn
  starting_position = "LATEST"
}

data "archive_file" "lambda_create" {
  type        = "zip"
  source_file = "${path.module}/lambda_create.py"
  output_path = "${path.module}/.lambda_create.zip"
}

data "archive_file" "lambda_delete" {
  type        = "zip"
  source_file = "${path.module}/lambda_delete.py"
  output_path = "${path.module}/.lambda_delete.zip"
}