variable log_forwarder_id {
  description = "Log Forwarder ID"
  type = string
}

variable resource_group {
  description = "A value for ResourceGroup tag on all resources. Can only contain numbers, lowercase letters, uppercase letters, ampersat(@) , hyphens (-), period (.), and hash (#). Max length is 64."
  type = string
  default = "Ghost"
}

variable "gcp_sts_sa_id" {
  description = "Identity used for log shipper"
  type = string
}