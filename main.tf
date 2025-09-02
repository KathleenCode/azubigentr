provider "aws" {
  region = "eu-north-1"  # Adjust as needed
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Input S3 Bucket (request-bucket)
resource "aws_s3_bucket" "request_bucket" {
  bucket = "request-bucket-${random_string.suffix.result}"
}

# Output S3 Bucket (response-bucket)
resource "aws_s3_bucket" "response_bucket" {
  bucket = "response-bucket-${random_string.suffix.result}"
}

# Block public access
resource "aws_s3_bucket_public_access_block" "request_block" {
  bucket = aws_s3_bucket.request_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_public_access_block" "response_block" {
  bucket = aws_s3_bucket.response_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# CORS for frontend access (allows JS from local/origin to upload/read)
resource "aws_s3_bucket_cors_configuration" "request_cors" {
  bucket = aws_s3_bucket.request_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]  # For local testing; restrict in prod (e.g., your domain)
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_cors_configuration" "response_cors" {
  bucket = aws_s3_bucket.response_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]  # For local testing
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# IAM Role and Policy (from Phase 1, with logs for Lambda)
resource "aws_iam_role" "translation_role" {
  name = "translation-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "translation_policy" {
  name = "translation-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.request_bucket.arn}/*" },
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.response_bucket.arn}/*" },
      { Effect = "Allow", Action = "translate:TranslateText", Resource = "*" },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "translation_attach" {
  role       = aws_iam_role.translation_role.name
  policy_arn = aws_iam_policy.translation_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "translation_lambda" {
  function_name = "translation-function"
  role          = aws_iam_role.translation_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  filename      = "lambda_function.zip"  # Create this in Step 2

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.response_bucket.bucket
    }
  }
}

# S3 Event Trigger
resource "aws_s3_bucket_notification" "request_notification" {
  bucket = aws_s3_bucket.request_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.translation_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translation_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.request_bucket.arn
}

# Outputs
output "request_bucket_name" {
  value = aws_s3_bucket.request_bucket.bucket
}

output "response_bucket_name" {
  value = aws_s3_bucket.response_bucket.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.translation_lambda.function_name
}