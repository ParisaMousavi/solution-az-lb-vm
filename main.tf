module "rg_name" {
  source             = "github.com/ParisaMousavi/az-naming//rg?ref=2022.10.07"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

module "resourcegroup" {
  # https://{PAT}@dev.azure.com/{organization}/{project}/_git/{repo-name}
  source   = "github.com/ParisaMousavi/az-resourcegroup?ref=2022.10.07"
  location = var.location
  name     = module.rg_name.result
  tags = {
    CostCenter = "ABC000CBA"
    By         = "parisamoosavinezhad@hotmail.com"
  }
}

#-----------------------------------------------
#  Deploy web servers
#-----------------------------------------------
module "vm_name" {
  source             = "github.com/ParisaMousavi/az-naming//vm?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

# resource "azurerm_public_ip" "this_win" {
#   name                = "${module.vm_name.result}-pip"
#   location            = module.resourcegroup.location
#   resource_group_name = module.resourcegroup.name
#   allocation_method   = "Static"

#   tags = {
#     environment = "Production"
#   }
# }

resource "azurerm_network_interface" "this_win" {
  name                = "${module.vm_name.result}-nic"
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name

  ip_configuration {
    primary                       = true
    name                          = "internal"
    subnet_id                     = data.terraform_remote_state.network.outputs.subnets["vm-win"].id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.this_win.id
  }
}


#----------------------------------------------
#       For Win Machine
#----------------------------------------------
module "nsg_win_name" {
  source             = "github.com/ParisaMousavi/az-naming//nsg?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  assembly           = "win"
  location_shortname = var.location_shortname
}

# Reference link: https://github.com/Flodu31/Terraform/blob/master/Deploy_New_Environment_Provisioners/modules/2-windows_vm/1-virtual-machine.tf
module "nsg_win" {
  source              = "github.com/ParisaMousavi/az-nsg-v2?ref=main"
  name                = module.nsg_win_name.result
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  security_rules = [
    {
      name                       = "HTTP"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      description                = "HTTP: Allow inbound from any to 80"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]
  additional_tags = {
    CostCenter = "ABC000CBA"
    By         = "parisamoosavinezhad@hotmail.com"
  }
}


resource "azurerm_network_interface_security_group_association" "this_win" {
  network_interface_id      = azurerm_network_interface.this_win.id
  network_security_group_id = module.nsg_win.id
}

resource "azurerm_windows_virtual_machine" "this_win" {
  name                = module.vm_name.result
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  size                = "Standard_D4s_v4" #"Standard_B2s" #"Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.this_win.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # az vm image list --all --publisher "MicrosoftWindowsServer" --location westeurope --offer "WindowsServer"
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

}

#used this link for installing IIS: https://github.com/MicrosoftLearning/AZ-104-MicrosoftAzureAdministrator/blob/master/Allfiles/Labs/08/az104-08-install_IIS.ps1
resource "azurerm_virtual_machine_extension" "example" {
  name                       = "vm_extension_install_iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.this_win.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  settings                   = <<SETTINGS
{
	"commandToExecute": "powershell.exe Install-WindowsFeature -name Web-Server -IncludeManagementTools && powershell.exe remove-item 'C:\\inetpub\\wwwroot\\iisstart.htm' && powershell.exe Add-Content -Path 'C:\\inetpub\\wwwroot\\iisstart.htm' -Value $($env:computername)"
}
SETTINGS
  tags = {
    CostCenter = "ABC000CBA"
    By         = "parisamoosavinezhad@hotmail.com"
  }
}



module "lb_pip_name" {
  source             = "github.com/ParisaMousavi/az-naming//pip?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

# https://terraformguru.com/terraform-real-world-on-azure-cloud/14-Azure-Standard-LoadBalancer-Basic/
resource "azurerm_public_ip" "example" {
  name                = module.lb_pip_name.result
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  allocation_method   = "Static"
  sku                 = "Basic"
}

module "lb_name" {
  source             = "github.com/ParisaMousavi/az-naming//lb?ref=main"
  prefix             = var.prefix
  name               = var.name
  stage              = var.stage
  location_shortname = var.location_shortname
}

resource "azurerm_lb" "example" {
  name                = module.lb_name.result
  location            = module.resourcegroup.location
  resource_group_name = module.resourcegroup.name
  sku                 = "Basic"
  sku_tier            = "Regional"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

resource "azurerm_lb_probe" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "HTTP_Backend_Probe"
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_backend_address_pool" "web_lb_backend_address_pool" {
  name            = "web-backend"
  loadbalancer_id = azurerm_lb.example.id
}

# Resource-5: Create LB Rule
resource "azurerm_lb_rule" "web_lb_rule_app1" {
  name                           = "web-app1-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id]
  probe_id                       = azurerm_lb_probe.example.id
  loadbalancer_id                = azurerm_lb.example.id
}

# Resource-6: Associate Network Interface and Standard Load Balancer
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association
resource "azurerm_network_interface_backend_address_pool_association" "web_nic_lb_associate" {
  network_interface_id    = azurerm_network_interface.this_win.id
  ip_configuration_name   = azurerm_network_interface.this_win.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.web_lb_backend_address_pool.id
}
