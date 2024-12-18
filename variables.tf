variable "resource_group" {
  description = "A value for ResourceGroup tag on all resources. Can only contain numbers, lowercase letters, uppercase letters, ampersat(@) , hyphens (-), period (.), and hash (#). Max length is 64."
  type        = string
  default     = "Ghost"
}

variable "name" {
  description = "The name for this log forwarder as it will be displayed in the Ghost platform UI."
  type        = string
}
