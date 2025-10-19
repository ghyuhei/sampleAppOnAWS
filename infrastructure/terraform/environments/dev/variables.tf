# ====================================
# Development Environment Variables
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
  description = "Email address for alerts (optional for dev)"
  type        = string
  default     = ""
}
