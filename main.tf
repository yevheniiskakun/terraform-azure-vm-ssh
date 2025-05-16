# Creating name for recource group using random provider declared in providers.tf
# To read more about random_pet metod https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/pet
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

# Creating resource group with mentioned tags, name and location picked up from variables.tf
resource "azurerm_resource_group" "my_rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
  tags = {
    environment = var.environment
    source      = "Terraform"
    owner       = "IT department"
  }
}

resource "azurerm_virtual_network" "mtc-vn" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.my_rg.name
  location            = var.resource_group_location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = var.environment
    source      = "Terraform"
    owner       = "IT department"
  }
}

resource "azurerm_subnet" "mtc-subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.my_rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-sg"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.my_rg.name

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_security_rule" "mtc-dev-rule" {
  name                        = "mtc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.my_rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}

resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnet.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
}


resource "azurerm_public_ip" "mtc-ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.my_rg.name
  location            = var.resource_group_location
  allocation_method   = "Dynamic"

  tags = {
    environment = var.environment
  }
}

resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.my_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-ip.id
  }

  tags = {
    environment = var.environment
  }
}

resource "azurerm_linux_virtual_machine" "mtc-vm" {
  name                = "mtc-vm"
  resource_group_name = azurerm_resource_group.my_rg.name
  location            = var.resource_group_location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.mtc-nic.id,
  ]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("mtcazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/${var.host_os}-ssh-script.tpl", {
        hostname = self.public_ip_address,
        user = "adminuser"
        identityfile = "mtcazurekey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }

  tags = {
    environment = var.environment
  }
}

data "azurerm_public_ip" "mtc-ip-data" {
  name = azurerm_public_ip.mtc-ip.name
  resource_group_name = azurerm_resource_group.my_rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.mtc-vm.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}
