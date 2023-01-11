#############################
## Application - Variables ##
#############################

# company name 
variable "company" {
  type        = string
  description = "This variable defines thecompany name used to build resources"
}

# application name 
variable "app_name" {
  type        = string
  description = "This variable defines the application name used to build resources"
}

# environment
variable "environment" {
  type        = string
  description = "This variable defines the environment to be built"
}

# azure region
variable "location" {
  type        = string
  description = "Azure region where the resource group will be created"
  default     = "north europe"
}

####################
## Network - Main ##
####################

# Create a resource group for network
resource "azurerm_resource_group" "network-rg" {
  name     = "linux-${lower(replace(var.app_name," ","-"))}-${var.environment}-rg"
  location = var.location
  tags = {
    application = var.app_name
    environment = var.environment
  }
}

# Create the network VNET
resource "azurerm_virtual_network" "network-vnet" {
  name                = "linux-${lower(replace(var.app_name," ","-"))}-${var.environment}-vnet"
  address_space       = [var.network-vnet-cidr]
  resource_group_name = azurerm_resource_group.network-rg.name
  location            = azurerm_resource_group.network-rg.location
  tags = {
    application = var.app_name
    environment = var.environment
  }
}

# Create a subnet for Network
resource "azurerm_subnet" "network-subnet" {
  name                 = "linux-${lower(replace(var.app_name," ","-"))}-${var.environment}-subnet"
  address_prefixes     = [var.network-subnet-cidr]
  virtual_network_name = azurerm_virtual_network.network-vnet.name
  resource_group_name  = azurerm_resource_group.network-rg.name
}

######################
## Network - Output ##
######################

output "network_resource_group_id" {
  value = azurerm_resource_group.network-rg.id
}

output "network_vnet_id" {
  value = azurerm_virtual_network.network-vnet.id
}

output "network_subnet_id" {
  value = azurerm_subnet.network-subnet.id
}

##############################
## Core Network - Variables ##
##############################

variable "network-vnet-cidr" {
  type        = string
  description = "The CIDR of the network VNET"
}

variable "network-subnet-cidr" {
  type        = string
  description = "The CIDR for the network subnet"
}

###########################
## Azure Provider - Main ##
###########################

# Define Terraform provider
terraform {
  required_version = "~> 1.0"
}

# Configure the Azure provider
provider "azurerm" { 
  features {}  
  environment     = "public"
  subscription_id = var.azure-subscription-id
  client_id       = var.azure-client-id
  client_secret   = var.azure-client-secret
  tenant_id       = var.azure-tenant-id
}

################################
## Azure Provider - Variables ##
################################

# Azure authentication variables

variable "azure-subscription-id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "azure-client-id" {
  type        = string
  description = "Azure Client ID"
}

variable "azure-client-secret" {
  type        = string
  description = "Azure Client Secret"
}

variable "azure-tenant-id" {
  type        = string
  description = "Azure Tenant ID"
}

####################
# Common Variables #
####################
company     = "kopicloud"
app_name    = "iac-test"
environment = "dev"
location    = "northeurope"

##################
# Authentication #
##################
azure-tenant-id       = "complete-this"
azure-subscription-id = "complete-this"
azure-client-id       = "complete-this"
azure-client-secret   = "complete-this"

###########
# Network #
###########
network-vnet-cidr   = "10.128.0.0/16"
network-subnet-cidr = "10.128.1.0/24"

##################
# VM Information #
##################
windows_vm_size        = "Standard_B2s"
windows_admin_username = "tfadmin"

#######################
## Windows VM - Main ##
#######################

# Generate randon name for the Windows VM
resource "random_string" "random-win-vm" {
  length  = 8
  special = false
  lower   = true
  upper   = false
  number  = true
}

# Create Network Security Group to Access the Windows VM from Internet
resource "azurerm_network_security_group" "windows-vm-nsg" {
  name                = "${lower(replace(var.app_name," ","-"))}-${var.environment}-windows-vm-nsg"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name

  security_rule {
    name                       = "allow-rdp"
    description                = "allow-rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*" 
  }

  security_rule {
    name                       = "allow-http"
    description                = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    application = var.app_name
    environment = var.environment 
  }
}

# Associate the NSG with the Subnet
resource "azurerm_subnet_network_security_group_association" "windows-vm-nsg-association" {
  depends_on=[azurerm_network_security_group.windows-vm-nsg]

  subnet_id                 = azurerm_subnet.network-subnet.id
  network_security_group_id = azurerm_network_security_group.windows-vm-nsg.id
}

# Get a Static Public IP for the Windows VM
resource "azurerm_public_ip" "windows-vm-ip" {
  name                = "win-${random_string.random-win-vm.result}-vm-ip"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  allocation_method   = "Static"
  
  tags = { 
    application = var.app_name
    environment = var.environment 
  }
}

# Create Network Card for the Windows VM
resource "azurerm_network_interface" "windows-vm-nic" {
  depends_on=[azurerm_public_ip.windows-vm-ip]

  name                = "win-${random_string.random-win-vm.result}-vm-nic"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.network-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows-vm-ip.id
  }

  tags = { 
    application = var.app_name
    environment = var.environment 
  }
}

# Create Windows Server
resource "azurerm_windows_virtual_machine" "windows-vm" {
  depends_on=[azurerm_network_interface.windows-vm-nic]

  name                  = "win-${random_string.random-win-vm.result}-vm"
  location              = azurerm_resource_group.network-rg.location
  resource_group_name   = azurerm_resource_group.network-rg.name
  size                  = var.windows_vm_size
  network_interface_ids = [azurerm_network_interface.windows-vm-nic.id]
  
  computer_name  = "win-${random_string.random-win-vm.result}-vm"
  admin_username = var.windows_admin_username
  admin_password = var.windows_admin_password

  os_disk {
    name                 = "win-${random_string.random-win-vm.result}-vm-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = var.windows_2022_sku
    version   = "latest"
  }

  enable_automatic_updates = true
  provision_vm_agent       = true

  tags = {
    application = var.app_name
    environment = var.environment 
  }
}

##############
## OS Image ##
##############

# Windows Server 2022 SKU used to build VMs
variable "windows_2022_sku" {
  type        = string
  description = "Windows Server 2022 SKU used to build VMs"
  default     = "2022-Datacenter"
}

# Windows Server 2019 SKU used to build VMs
variable "windows_2019_sku" {
  type        = string
  description = "Windows Server 2019 SKU used to build VMs"
  default     = "2019-Datacenter"
}

# Windows Server 2016 SKU used to build VMs
variable "windows_2016_sku" {
  type        = string
  description = "Windows Server 2016 SKU used to build VMs"
  default     = "2016-Datacenter"
}

# Windows Server 2012 R2 SKU used to build VMs
variable "windows_2012_r2_sku" {
  type        = string
  description = "Windows Server 2012 R2 SKU used to build VMs"
  default     = "2012-R2-Datacenter"
}

# Windows Server 2012 SKU used to build VMs
variable "windows_2012_sku" {
  type        = string
  description = "Windows Server 2012 SKU used to build VMs"
  default     = "2012-Datacenter"
}

# Windows Server 2008 R2 SKU used to build VMs
variable "windows_2008_sku" {
  type        = string
  description = "Windows Server 2008 R2 SP1 SKU used to build VMs"
  default     = "2008-R2-SP1"
}

#########################
## Windows VM - Output ##
#########################

# Windows VM ID
output "windows_vm_id" {
  value = azurerm_windows_virtual_machine.windows-vm.id
}

# Web Windows VM Name
output "windows_vm_name" {
  value = azurerm_windows_virtual_machine.windows-vm.name
}

# Web Windows VM Admin Username
output "windows_vm_admin_username" {
  value = var.windows_admin_username
}

# Web Windows VM Admin Password
output "windows_vm_admin_password" {
  value = var.windows_admin_password
}

# Web Windows VM Public IP
output "windows_vm_public_ip" {
  value = azurerm_public_ip.windows-vm-ip.ip_address
}

############################
## Windows VM - Variables ##
############################

# Windows VM Admin User
variable "windows_admin_username" {
  type        = string
  description = "Windows VM Admin User"
  default     = "tfadmin"
}

# Windows VM Admin Password
variable "windows_admin_password" {
  type        = string
  description = "Windows VM Admin Password"
  default     = "S3cr3ts24"
}

# Windows VM Virtual Machine Size
variable "windows_vm_size" {
  type        = string
  description = "Windows VM Size"
  default     = "Standard_B1s"
}

variable "windows_delete_os_disk_on_termination" {
  type        = string
  description = "Should the OS Disk (either the Managed Disk / VHD Blob) be deleted when the Virtual Machine is destroyed?"
  default     = "true"  # Update for your environment
}

variable "windows_delete_data_disks_on_termination" {
  description = "Should the Data Disks (either the Managed Disks / VHD Blobs) be deleted when the Virtual Machine is destroyed?"
  type        = string
  default     = "true" # Update for your environment
}
