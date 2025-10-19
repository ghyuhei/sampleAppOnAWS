variable "project_name" {
  description = "Project name"
  type        = string
}

variable "rate_limit" {
  description = "Rate limit per 5 minutes per IP"
  type        = number
  default     = 2000
}

variable "blocked_countries" {
  description = "List of country codes to block"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "WAF log retention in days"
  type        = number
  default     = 7
}
