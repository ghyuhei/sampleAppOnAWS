# ====================================
# Staging Environment Variables
# ====================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "nextjs-ecs"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = null
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email != ""
    error_message = "Alert email is required for staging environment."
  }
}
