# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = var.network_name
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  # Open port 22 for SSH connection
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # or restrict to your IP
    destination_address_prefix = "*"
  }

  # open port 9870 for inbound traffic so we can access the HDFS NameNode Web UI for monitoring HDFS.
  security_rule {
    name                       = "HDFS_NameNode"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9870"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # open port 9868 for inbound traffic so we can access the HDFS Secondary NameNode UI for monitoring Secondary NameNode.
  security_rule {
    name                       = "HDFS_Secondary_NameNode"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9868"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # open port 8088 for inbound traffic so we can access the ResourceManager UI (YARN) for using the YARN Resource Manager.
  security_rule {
    name                       = "YARN_ResourceManager"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8088"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # open port 8042 for inbound traffic so we can access the NodeManager Web UI for NodeManager monitoring.
  security_rule {
    name                       = "HDFS_NodeManager"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8042"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # open port 9864 for inbound traffic so we can access the DataNode UI for DataNode monitoring.
  security_rule {
    name                       = "HDFS_DataNode"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9864"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # open port 8080 for inbound traffic so we can access the Spark Master Web UI for monitoring cluster.
  security_rule {
    name                       = "SparkMaster"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # open port 8081 for inbound traffic so we can access the Spark Worker Web UI for monitoring workers.
  security_rule {
    name                       = "SparkWorkers"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8081"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # open port 18080 for inbound traffic so we can access the Spark History Server to view completed Spark jobs history.
  security_rule {
    name                       = "SparkHistory"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "18080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Oper port 8888 for inbound traffic so we can access the Jupyter Notebook.
  security_rule {
    name                       = "Allow-Jupyter"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8888"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}