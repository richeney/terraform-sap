output "ssh" {
  value = "ssh azureuser@${azurerm_public_ip.temp.ip_address}"
  depends_on = [ azurerm_linux_virtual_machine.temp, ]
}