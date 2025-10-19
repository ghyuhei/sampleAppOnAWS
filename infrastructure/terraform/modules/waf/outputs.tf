output "web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.cloudfront.id
}

output "web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.cloudfront.arn
}

output "log_group_name" {
  description = "CloudWatch Log Group name for WAF"
  value       = aws_cloudwatch_log_group.waf.name
}
