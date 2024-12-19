variable "name" {
  description = "The name for this log forwarder as it will be displayed in the Ghost platform UI."
  type        = string
}

variable "tags" {
  description = "Map of tags to assign to all resources. By default resources are tagged with ghost:log_forwarder_id and ghost:forwarder_name."
  type        = map(string)
  default     = {}
}
