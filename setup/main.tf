// This Terraform config creates a server and access to the NFS share
// This allows the SAP Hana binaries to be downloaded and then copied
// as per the SETUP.md file.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 2.38"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "demo_resources" {
  name = "sap_hana_demo_resources"
}

data "azurerm_storage_account" "nfs" {
  name                = data.azurerm_resource_group.demo_resources.tags.storage_account
  resource_group_name = data.azurerm_resource_group.demo_resources.name
}

data "azurerm_key_vault" "demo_resources" {
  name                = data.azurerm_resource_group.demo_resources.tags.key_vault
  resource_group_name = data.azurerm_resource_group.demo_resources.name
}

data "azurerm_user_assigned_identity" "sap_hana_demo" {
  name                = "sap_hana_demo"
  resource_group_name = data.azurerm_resource_group.demo_resources.name
}

data "azurerm_image" "bootstrap" {
  name                = "sap_hana_bootstrap_server"
  resource_group_name = data.azurerm_resource_group.demo_resources.name
}

resource "azurerm_virtual_network" "temp" {
  name                = var.name
  location            = data.azurerm_resource_group.demo_resources.location
  resource_group_name = data.azurerm_resource_group.demo_resources.name
  address_space       = ["10.240.0.0/26"]
}

resource "azurerm_subnet" "temp" {
  name                 = var.name
  resource_group_name  = data.azurerm_resource_group.demo_resources.name
  virtual_network_name = azurerm_virtual_network.temp.name
  address_prefixes     = ["10.240.0.0/27"]

  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_private_endpoint" "temp" {
  name                = var.name
  location            = data.azurerm_resource_group.demo_resources.location
  resource_group_name = data.azurerm_resource_group.demo_resources.name
  subnet_id           = azurerm_subnet.temp.id

  private_service_connection {
    name                           = "${data.azurerm_storage_account.nfs.name}-connection"
    private_connection_resource_id = data.azurerm_storage_account.nfs.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }
}

//=============================================================================================

// Use the bootstrap image for a temporary server so that the user can log on,
// download the SAP Hana binaries and upload into the NFS share

resource "azurerm_public_ip" "temp" {
  name                = "${var.name}-pip"
  location            = data.azurerm_resource_group.demo_resources.location
  resource_group_name = data.azurerm_resource_group.demo_resources.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "temp" {
  name                = "${var.name}-nsg"
  location            = data.azurerm_resource_group.demo_resources.location
  resource_group_name = data.azurerm_resource_group.demo_resources.name

  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.source_address_prefix
    source_port_range          = "*"
    destination_port_range     = "22"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "temp" {
  name                = "${var.name}-nic"
  location            = data.azurerm_resource_group.demo_resources.location
  resource_group_name = data.azurerm_resource_group.demo_resources.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.temp.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.temp.id
  }
}

resource "azurerm_network_interface_security_group_association" "temp" {
  network_interface_id      = azurerm_network_interface.temp.id
  network_security_group_id = azurerm_network_security_group.temp.id
}

resource "azurerm_linux_virtual_machine" "temp" {
  name                  = var.name
  location              = data.azurerm_resource_group.demo_resources.location
  resource_group_name   = data.azurerm_resource_group.demo_resources.name
  network_interface_ids = [azurerm_network_interface.temp.id]
  size                  = "Standard_D2s_v3"

  os_disk {
    name                 = "${var.name}-os"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_id = data.azurerm_image.bootstrap.id

  custom_data = base64encode(templatefile("${path.module}//cloud-init.tpl", {
    hostname   = var.name,
    adminuser  = var.adminuser,
    sshkey     = file(var.ssh_pub_key_file),
    lun        = var.lun,
    mountpoint = var.mountpoint,
  }))

  computer_name                   = var.name
  admin_username                  = var.adminuser
  disable_password_authentication = true

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.sap_hana_demo.id]
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

resource "azurerm_managed_disk" "temp" {
  name                 = "${var.name}-data"
  location             = data.azurerm_resource_group.demo_resources.location
  resource_group_name  = data.azurerm_resource_group.demo_resources.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 40
}

resource "azurerm_virtual_machine_data_disk_attachment" "temp" {
  managed_disk_id    = azurerm_managed_disk.temp.id
  virtual_machine_id = azurerm_linux_virtual_machine.temp.id
  lun                = "1"
  caching            = "ReadWrite"
}
