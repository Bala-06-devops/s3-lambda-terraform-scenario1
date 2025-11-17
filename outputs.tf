output "s3_bucket_name" {
  value = aws_s3_bucket.bucket.id
}

output "lambda_arn" {
  value = aws_lambda_function.lambda.arn
}
