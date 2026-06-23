provider "aws" {
  region = "us-east-1"
}

# ── DynamoDB Table ──────────────────────────────────────────
resource "aws_dynamodb_table" "unique_data_store" {
  name         = "UniqueDataStore"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "data_hash"

  attribute {
    name = "data_hash"
    type = "S"
  }

  tags = {
    Project = "HorizonTechX-Task1"
  }
}

# ── IAM Role for Lambda ─────────────────────────────────────
resource "aws_iam_role" "lambda_role" {
  name = "task1_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# ── Lambda Function ─────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

resource "aws_lambda_function" "data_redundancy" {
  filename         = "lambda_function.zip"
  function_name    = "DataRedundancyRemover"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.unique_data_store.name
    }
  }
}

# ── API Gateway REST API ────────────────────────────────────
resource "aws_api_gateway_rest_api" "task1_api" {
  name = "DataRedundancyAPI"
}

# ── /check Resource ─────────────────────────────────────────
resource "aws_api_gateway_resource" "check" {
  rest_api_id = aws_api_gateway_rest_api.task1_api.id
  parent_id   = aws_api_gateway_rest_api.task1_api.root_resource_id
  path_part   = "check"
}

# ── POST Method ─────────────────────────────────────────────
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.task1_api.id
  resource_id   = aws_api_gateway_resource.check.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task1_api.id
  resource_id             = aws_api_gateway_resource.check.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.data_redundancy.invoke_arn
}

# ── GET Method ──────────────────────────────────────────────
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.task1_api.id
  resource_id   = aws_api_gateway_resource.check.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.data" = false
  }
}

resource "aws_api_gateway_integration" "get_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task1_api.id
  resource_id             = aws_api_gateway_resource.check.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.data_redundancy.invoke_arn
}

# ── Lambda Permission ───────────────────────────────────────
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_redundancy.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.task1_api.execution_arn}/*/*"
}

# ── Deployment ──────────────────────────────────────────────
resource "aws_api_gateway_deployment" "task1_deploy" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.get_lambda_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.task1_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.check.id,
      aws_api_gateway_method.post_method.id,
      aws_api_gateway_method.get_method.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_integration.get_lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ── Stage ───────────────────────────────────────────────────
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.task1_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.task1_api.id
  stage_name    = "prod"
}
