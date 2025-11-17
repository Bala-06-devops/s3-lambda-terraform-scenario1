provider "aws" {
  region  = "us-east-1"
}

# S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  tags = {
    Environment = var.environment
  }
  }


# Block public access
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/s3FileProcessor"
  retention_in_days = 14
  tags = {
    Environment = var.environment
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "raju"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Environment = var.environment }
}

# Attach policies
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name   = "lambda-s3-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.bucket.arn}/*" },
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.bucket.arn }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# Zip Lambda folder
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "lambda" {
  function_name = "s3FileProcessor"
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role = aws_iam_role.lambda_role.arn
  tags = { Environment = var.environment }
}

# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  action        = "lambda:InvokeFunction"
  principal     = "s3.amazonaws.com"
  function_name = aws_lambda_function.lambda.function_name
  source_arn    = aws_s3_bucket.bucket.arn
}

# S3 bucket notification
resource "aws_s3_bucket_notification" "notify" {
  bucket = aws_s3_bucket.bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}
