variable "name" {
  type        = string
  default     = "temporary"
  description = "Name for the VM and resources."
}

variable "adminuser" {
  type        = string
  default     = "azureuser"
  description = "Name for the VM's admin user."
}

variable "lun" {
  type        = number
  default     = 1
  description = "LUN number of the data disk."
}

variable "mountpoint" {
  type        = string
  default     = "/data"
  description = "Mountpoint for the data disk."
}



variable "ssh_pub_key_file" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Path to the public SSH key."
}

variable "source_address_prefix" {
  type        = string
  default     = "*"
  description = "Set to restrict source public IP address: e.g. `dig +short myip.opendns.com @resolver1.opendns.com`, https://www.whatismyip-address.com"
}
