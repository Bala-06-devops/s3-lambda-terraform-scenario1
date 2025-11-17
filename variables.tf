variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket to be created"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev)"
}
