# ====================================
# Production Environment Variables
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

variable "alert_email" {
  description = "Email address for alerts (REQUIRED for production)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Alert email must be a valid email address. This is required for production environment."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (REQUIRED for production)"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:acm:", var.certificate_arn))
    error_message = "Certificate ARN must be a valid ACM certificate ARN. This is required for production environment."
  }
}
