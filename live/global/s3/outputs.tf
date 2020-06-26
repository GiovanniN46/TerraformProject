output "s3_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
  description = "L'ARN del bucket s3"
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
  description = "Il nome della DynamoDB table"
}
