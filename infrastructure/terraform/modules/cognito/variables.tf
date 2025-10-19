variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_mfa" {
  description = "Enable MFA for user pool"
  type        = bool
  default     = true
}

variable "admin_create_user_only" {
  description = "Only allow administrators to create users"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection for user pool"
  type        = bool
  default     = true
}

variable "advanced_security_mode" {
  description = "Advanced security mode (OFF, AUDIT, ENFORCED)"
  type        = string
  default     = "ENFORCED"

  validation {
    condition     = contains(["OFF", "AUDIT", "ENFORCED"], var.advanced_security_mode)
    error_message = "Advanced security mode must be OFF, AUDIT, or ENFORCED."
  }
}

variable "callback_urls" {
  description = "List of allowed callback URLs for the user pool client"
  type        = list(string)
}

variable "logout_urls" {
  description = "List of allowed logout URLs for the user pool client"
  type        = list(string)
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}
