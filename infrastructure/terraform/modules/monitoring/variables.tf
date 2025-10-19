# ====================================
# Monitoring Module Variables
# ====================================

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target Group ARN suffix for CloudWatch metrics"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Logs group name"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "rds_instance_id" {
  description = "RDS instance identifier for monitoring"
  type        = string
  default     = ""
}

variable "enable_canary" {
  description = "Enable CloudWatch Synthetics Canary"
  type        = bool
  default     = false
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "ecs_task_role_name" {
  description = "ECS task role name for X-Ray permissions"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}
