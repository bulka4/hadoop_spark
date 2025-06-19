module "resource_group" {
  source = "./modules/resource_group"
  name = var.resource_group_name
  location = var.resource_group_location
}

# Prepare networks for our VMs.
module "networks" {
  source = "./modules/networks"
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location
}

# Generate ssh keys for connecting from our local computer to both VMs. Save the private key on our
# local computer at the path specified by the ssh_path.
module "ssh_1"{
  source = "./modules/ssh"
  resource_group_id = module.resource_group.id
  resource_group_location = module.resource_group.location
  ssh_path = var.ssh_path
}

# Generate SSH keys for communication between created VMs. Private key will be saved on one VM (vm_1) and the public key
# will be saved on the another VM (vm_2) by executing bash scripts on them.
module "ssh_2" {
  source = "./modules/ssh"
  resource_group_id = module.resource_group.id
  resource_group_location = module.resource_group.location
}

module "storage_account" {
  source = "./modules/storage_account"
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location
}

# Prepare the first VM. It will act as a master node.
module "linux_vm_1" {
  source = "./modules/linux_vm"
  
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location

  vm_name = "vm_1"
  hostname = var.hostnames[0] # hostname of the Master Node
  subnet_id = module.networks.subnet_id
  nsg_id = module.networks.nsg_id

  username = var.vm_username
  public_key = module.ssh_1.public_key # Public SSH key for connecting to that VM from our local computer.

  storage_account_uri = module.storage_account.primary_blob_endpoint
}

# Prepare the second VM. It will act as a slave node.
module "linux_vm_2" {
  source = "./modules/linux_vm"
  
  resource_group_name = module.resource_group.name
  resource_group_location = module.resource_group.location

  vm_name = "vm_2"
  hostname = var.hostnames[1] # hostname of the Slave Node
  subnet_id = module.networks.subnet_id
  nsg_id = module.networks.nsg_id

  username = var.vm_username
  public_key = module.ssh_1.public_key

  storage_account_uri = module.storage_account.primary_blob_endpoint
}

locals {
  # hosts_entries are lines we want to add to the /etc/hosts file on VMs to assign
  # hosts names to private IP addresses.
  host_entries = [
    for ip_address, hostname in zipmap(
      [module.linux_vm_1.private_ip_address, module.linux_vm_2.private_ip_address]
      ,var.hostnames
    ) :
    "${ip_address} ${hostname}"
  ]
}

# Execute bash scripts on the created VMs using the azurerm_virtual_machine_extension resource which uses Azure VM Extension.

# Save the private SSH key on the VM1, add the public SSH key to the authoriezed_keys and configure Hadoop files.
# VM1 needs to be able to connect to the localhost and to the VM2 through SSH.
resource "azurerm_virtual_machine_extension" "vm1_configure_hadoop" {
  name                 = "vm1_configure_hadoop"
  virtual_machine_id   = module.linux_vm_1.vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  protected_settings = jsonencode({
    script = base64encode(templatefile("bash_scripts/vm1/configure_hadoop.tftpl", {
      username = var.vm_username
      hostnames = var.hostnames
      host_entries = local.host_entries
      ssh_private_key = module.ssh_2.private_key
      ssh_public_key = module.ssh_2.public_key
    }))
  })
}

# Save the public SSH key on the VM2 and edit etc/hosts file.
resource "azurerm_virtual_machine_extension" "vm2_configure_hadoop" {
  name                 = "vm2_configure_hadoop"
  virtual_machine_id   = module.linux_vm_2.vm_id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  protected_settings = jsonencode({
    script = base64encode(templatefile("bash_scripts/vm2/configure_hadoop.tftpl", {
      username = var.vm_username
      hostnames = var.hostnames
      host_entries = local.host_entries
      ssh_public_key = module.ssh_2.public_key
    }))
  })
}