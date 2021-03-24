output "ssh" {
  value      = "ssh azureuser@${azurerm_public_ip.temp.ip_address}"
  depends_on = [azurerm_linux_virtual_machine.temp, ]
}

output "private_endpoint_ip" {
  value = data.azurerm_private_endpoint_connection.temp.private_service_connection.0.private_ip_address
}

output "cloud_init" {
  value = local.cloud_init
}