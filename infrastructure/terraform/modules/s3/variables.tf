variable "project_name" {
  description = "Project name"
  type        = string
}

variable "allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN for bucket policy"
  type        = string
  default     = ""
}
