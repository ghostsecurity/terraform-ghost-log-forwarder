variable "name" {
  description = "The name for this log forwarder as it will be displayed in the Ghost platform UI."
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
