# ====================================
# Secrets Manager Module Variables
# ====================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring for secrets access"
  type        = bool
  default     = false
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
