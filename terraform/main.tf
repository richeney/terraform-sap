locals {
  subnet_address_prefix = cidrsubnet(var.address_space, 1, 0)
  bootstrap_ip_address  = cidrhost(local.subnet_address_prefix, 4)
  saphana01_ip_address  = cidrhost(local.subnet_address_prefix, 5)
  saphana02_ip_address  = cidrhost(local.subnet_address_prefix, 6)
}

data "azurerm_image" "bootstrap" {
  resource_group_name = var.bootstrap_image.resource_group_name
  name                = var.bootstrap_image.name
}

resource "azurerm_resource_group" "hana" {
  name     = "sap_hana_demo"
  location = "UK South"
}

resource "azurerm_virtual_network" "hana" {
  name                = "sap_hana_demo"
  location            = azurerm_resource_group.hana.location
  resource_group_name = azurerm_resource_group.hana.name
  address_space       = [var.address_space]
}

resource "azurerm_subnet" "hana" {
  name                 = "sap_hana_demo"
  resource_group_name  = azurerm_resource_group.hana.name
  virtual_network_name = azurerm_virtual_network.hana.name
  address_prefixes     = [local.subnet_address_prefix]

  enforce_private_link_endpoint_network_policies = true
}



/*
resource "azurerm_private_endpoint" "hana" {
  name                = "sap_hana_media_access"
  location            = azurerm_resource_group.hana.location
  resource_group_name = azurerm_resource_group.hana.name
  subnet_id           = azurerm_subnet.hana.id

  private_service_connection {
    name                           = "pmsaphanamediaaccess"
    private_connection_resource_id = "/subscriptions/d02a8eec-65d3-4e04-8599-190b908720bc/resourceGroups/ResourceGroupHANA/providers/Microsoft.Network/privateEndpoints/pmsaphanamediaaccess"
    is_manual_connection           = false
  }
}
*/

//=============================================================================================

// Bootstrap server

resource "azurerm_public_ip" "bootstrap" {
  name                = "bootstrap-pip"
  location            = azurerm_resource_group.hana.location
  resource_group_name = azurerm_resource_group.hana.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "bootstrap" {
  name                = "bootstrap-nsg"
  location            = azurerm_resource_group.hana.location
  resource_group_name = azurerm_resource_group.hana.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "bootstrap" {
  name                = "bootstrap-nic"
  location            = azurerm_resource_group.hana.location
  resource_group_name = azurerm_resource_group.hana.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.hana.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.bootstrap_ip_address
    public_ip_address_id          = azurerm_public_ip.bootstrap.id
  }
}

resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.bootstrap.id
  network_security_group_id = azurerm_network_security_group.bootstrap.id
}

resource "azurerm_linux_virtual_machine" "bootstrap" {
  name                  = "bootstrap"
  location              = azurerm_resource_group.hana.location
  resource_group_name   = azurerm_resource_group.hana.name
  network_interface_ids = [azurerm_network_interface.bootstrap.id]
  size                  = "Standard_D2s_v3"

  os_disk {
    name                 = "bootstrap-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = data.azurerm_image.bootstrap.id

  computer_name                   = "boostrap"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}
