variable "location" {
  type    = string
  default = "westeurope"
}

variable "prefix" {
  description = "This can be a team name as well."
  type        = string
  default     = "tmb"
}

variable "stage" {
  type    = string
  default = "dev"
}

variable "name" {
  type    = string
  default = "lvm"
}

variable "location_shortname" {
  type    = string
  default = "weu"
}

variable "remote_state_storage_account_name" {
  type    = string
  default = "parisatfstateaziac2weu"
}

variable "remote_state_resource_group_name" {
  type    = string
  default = "tfstate"
}
