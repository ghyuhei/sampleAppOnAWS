# ====================================
# Cost Management Module Variables
# ====================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_budgets" {
  description = "Enable AWS Budgets"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 500
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = []
}

variable "enable_anomaly_detection" {
  description = "Enable cost anomaly detection"
  type        = bool
  default     = true
}

variable "anomaly_threshold" {
  description = "Threshold for anomaly detection in USD"
  type        = number
  default     = 100
}

variable "enable_cur" {
  description = "Enable Cost and Usage Report"
  type        = bool
  default     = false
}

variable "enable_cost_alarms" {
  description = "Enable cost CloudWatch alarms"
  type        = bool
  default     = true
}

variable "daily_cost_threshold" {
  description = "Daily cost threshold for alarms in USD"
  type        = number
  default     = 50
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for cost alerts"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
