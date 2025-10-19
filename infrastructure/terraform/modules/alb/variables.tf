variable "project_name" {
  description = "Project name to be used as a prefix for resources"
  type        = string

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier (vpc-xxxxxx)."
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB placement"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnets are required for ALB high availability."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener (optional, enables HTTPS if provided)"
  type        = string
  default     = null

  validation {
    condition = var.certificate_arn == null || can(regex(
      "^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[a-z0-9-]+$",
      var.certificate_arn
    ))
    error_message = "Certificate ARN must be a valid ACM certificate ARN or null."
  }
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for ALB authentication"
  type        = string
  default     = ""
}

variable "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID for ALB authentication"
  type        = string
  default     = ""
}

variable "cognito_user_pool_domain" {
  description = "Cognito User Pool Domain for ALB authentication"
  type        = string
  default     = ""
}

variable "enable_cognito_auth" {
  description = "Enable Cognito authentication on ALB"
  type        = bool
  default     = false
}
