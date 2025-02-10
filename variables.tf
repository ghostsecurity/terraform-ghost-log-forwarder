variable "name" {
  description = "The name for this log forwarder. This must be unique within your AWS account."
  type        = string
  validation {
    condition     = length(var.name) <= 50 && can(regex("^[A-Za-z0-9-]+$", var.name))
    error_message = "Name can only contain alphanumeric characters and hyphens."
  }
}

variable "tags" {
  description = "Map of tags to assign to all resources. By default resources are tagged with ghost:forwarder_id and ghost:forwarder_name."
  type        = map(string)
  default     = {}
}

variable "api_url" {
  description = "Base URL for the Ghost API"
  type        = string
  default     = "https://api.ghostsecurity.com"
}

variable "api_key_secret_arn" {
  description = "ARN of a secret in AWS secrets manager that contains a Ghost API key with write:logs permissions"
  type        = string
}
