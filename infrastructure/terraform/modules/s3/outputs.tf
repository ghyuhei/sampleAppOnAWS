output "bucket_id" {
  description = "S3 bucket ID"
  value       = aws_s3_bucket.static_assets.id
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.static_assets.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.static_assets.arn
}

output "bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.static_assets.bucket_regional_domain_name
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.static_assets.bucket_regional_domain_name
}

output "origin_access_control_id" {
  description = "CloudFront Origin Access Control ID"
  value       = aws_cloudfront_origin_access_control.static_assets.id
}
