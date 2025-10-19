variable "project_name" {
  description = "Project name"
  type        = string
}

variable "alb_domain_name" {
  description = "ALB domain name"
  type        = string
}

variable "s3_bucket_domain_name" {
  description = "S3 bucket domain name"
  type        = string
}

variable "s3_origin_access_control_id" {
  description = "S3 Origin Access Control ID"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  type        = string
}

variable "custom_header_value" {
  description = "Custom header value for origin verification"
  type        = string
  sensitive   = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN (us-east-1)"
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 7
}
