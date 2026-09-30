terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}
provider "aws" {
  region = "eu-north-1"
}
# 1. DynamoDB Tablosu
resource "aws_dynamodb_table" "latency_metrics" {
  name         = "InternetLatencyMetrics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Region"
  range_key    = "Timestamp"
  attribute {
    name = "Region"
    type = "S"
  }
  attribute {
    name = "Timestamp"
    type = "N"
  }
  tags = {
    Project = "multi-region-internet-observability"
  }
}
# 2. IAM Rolü
resource "aws_iam_role" "lambda_exec_role" {
  name = "latency_probe_exec_role_v3"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
# 3. CloudWatch Log Politikası
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
# 4. DynamoDB Yazma Politikası
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "latency_probe_dynamodb_policy_v3"
  description = "Allows Lambda to put metrics into DynamoDB"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.latency_metrics.arn
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}
# 5. Lambda Kodu
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/probe_deploy.zip"
  source {
    content = <<-EOF
import json
import time
import os
import urllib.request
import boto3
dynamodb = boto3.resource('dynamodb', region_name='eu-north-1')
table = dynamodb.Table('InternetLatencyMetrics')
def lambda_handler(event, context):
    target_url = "https://www.google.com"
    start_time = time.time()
    status_code = 0


    try:
        req = urllib.request.Request(target_url, headers={'User-Agent': 'AWS-Latency-Probe'})
        with urllib.request.urlopen(req, timeout=5) as response:
            status_code = response.getcode()
        latency = round((time.time() - start_time) * 1000, 2)
    except Exception as e:
        latency = -1.0
        status_code = 500
    timestamp = int(time.time())
    region = os.environ.get('AWS_REGION', 'eu-north-1')
    table.put_item(
        Item={
            'Region': region,
            'Timestamp': timestamp,
            'LatencyMs': str(latency),
            'StatusCode': status_code
        }
    )
    return {
        'statusCode': 200,
        'body': json.dumps({'region': region, 'latency': latency, 'status': status_code})
    }
EOF
    filename = "probe.py"
  }
}
# 6. Stockholm Lambda Fonksiyonu
resource "aws_lambda_function" "latency_probe_stockholm" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "latency-probe-stockholm"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "probe.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10
  tags = {
    Project = "multi-region-internet-observability"
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_logs,
    aws_iam_role_policy_attachment.lambda_dynamodb_attach
  ]
}
# 7. EventBridge Zamanlayıcısı
resource "aws_cloudwatch_event_rule" "every_5_minutes" {
  name                = "latency_probe_every_5_minutes"
  description         = "Trigger Stockholm latency probe every 5 minutes"
  schedule_expression = "rate(5 minutes)"
}
resource "aws_cloudwatch_event_target" "trigger_stockholm_lambda" {
  rule      = aws_cloudwatch_event_rule.every_5_minutes.name
  target_id = "latency_probe_stockholm"
  arn       = aws_lambda_function.latency_probe_stockholm.arn
}
resource "aws_lambda_permission" "allow_eventbridge_stockholm" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.latency_probe_stockholm.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_5_minutes.arn
}