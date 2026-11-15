variable "name_prefix" {
  description = "Lowercase resource prefix shared by both environments"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,11}$", var.name_prefix))
    error_message = "Use 1 to 12 lowercase letters, digits, or hyphens, starting with a letter or digit."
  }
}

variable "env" {
  description = "Deployment environment"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod."
  }
}

variable "vpc_cidr" {
  description = "Environment VPC range"
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "image_tag" {
  description = "Immutable image tag, normally the Git commit SHA"
  type        = string
}

variable "option_a" {
  description = "First voting option"
  type        = string
  default     = "ביבי"
}

variable "option_b" {
  description = "Second voting option"
  type        = string
  default     = "אייזנקוט"
}

variable "desired_count" {
  description = "Number of tasks per service"
  type        = number
  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be at least 1."
  }
}
