variable "resource_group_location" {
  type        = string
  default     = "southafricanorth" # region where resources will be deployed. Can be get from https://www.jlaundry.nz/2022/azure_region_abbreviations/
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Name of the environment where recource is belong"
}

variable "host_os" {
  type        = string
  default     = "linux"
  description = "Host used in providion script"
}