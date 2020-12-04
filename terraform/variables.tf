variable "address_space" {
  type    = string
  default = "10.0.0.0/24"
}

variable "bootstrap_image" {
  type = object({
    resource_group_name = string
    name                = string
  })

  default = {
    resource_group_name = "sap_hana_images"
    name                = "sap_hana_bootstrap_server"
  }
}
