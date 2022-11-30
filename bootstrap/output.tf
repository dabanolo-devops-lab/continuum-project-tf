output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value = aws_dynamodb_table.tf-state-lock.id
}

output "state_bucket_name" {
  description = "The name of the S3 bucket for state"
  value = aws_s3_bucket.private_bucket.id
}