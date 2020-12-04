output "ssh" {
    value = "ssh azureuser@${azurerm_public_ip.bootstrap.ip_address}"
}