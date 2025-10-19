variable "project_name" {
  description = "Project name to be used as a prefix for resources"
  type        = string

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

variable "vpc_id" {
  description = "VPC ID where ECS resources will be created"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-z0-9]+$", var.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier (vpc-xxxxxx)."
  }
}

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS Managed Instances"
  type        = string
  default     = "t3.medium"
}
