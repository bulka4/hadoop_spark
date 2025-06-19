# Introduction
In this repository we have:
- Terraform scripts for creating Linux VMs in Azure.
- Bash scripts for setting up Hadoop and Spark on those VMs. 

We will create two Linux VMs. One will act as a master and one as a slave node.

# Repository guide
Here is a guide describing how to use this code.

## Creating Azure Linux VMs
In order to create VMs using Terraform we need to run the following commands:
>- terraform init # only when running Terraform for the first time in this repository
>- terraform plan -out main.tfplan
>- terraform apply main.tfplan

In order to destroy all the created resources in Azure we need to run the following commands:
>- terraform plan -destroy -out main.destroy.tfplan
>- terraform apply main.destroy.tfplan

## Starting Hadoop cluster
In order to start the Hadoop cluster we need to connect through SSH to the VM which acts as a master (VM1 by default) and run the following commands:
- hdfs namenode -format
- start-dfs.sh
- start-yarn.sh

In order to learn about how to connect to that VM through SSH reference to the 'SSH' section below in this documentation.

# Prerequisites
## Terraform configuration
We need to configure properly Terraform so it can create resources in our Azure subscription, it is described here: [developer.hashicorp.com](https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build).

If we want to optionally allow Terraform to create Service Principals we can follow the steps described below in the 'Allowing Terraform for creating Service Principals' section. It is not needed for setting up Hadoop and Spark.

### Allowing Terraform for creating Service Principals 
When Terraform is creating Azure resources it is authenticating using a Service Principal. In order to allow Terraform to create other Service Principals, we need to create a Service Principal with proper permissions which will be used by Terraform for authentication. 

In the ‘Authenticate using the Azure CLI > Create a Service Principal’ section in the instruction on developer.hashicorp.com we are creating a service principal with the ‘Contributor’ Azure role and we need to change it into ‘Owner’.

Also it is useful to add some name to the created service principal, for example ‘Terraform’. We can do this by using the ‘az ad sp create-for-rbac’ command with the ‘--name’ parameter.

Additionaly we need to assign the ‘Application Administrator’ Entra role to that service principal. It is described here how to do this: [docs.azure.cn](https://docs.azure.cn/en-us/entra/identity/role-based-access-control/manage-roles-portal?tabs=admin-center)

## Azure subscription
We need to have a subscription on the Azure platform portal.azure.com.

# Code description
In the below sections we can find more details about how the code works.

## SSH
The Terraform code will generate SSH keys pair, save the private key on our local computer and add the public key to the authorized keys on the created VMs.

Then we can connect to the created VMs by using this command on our local computer:
>ssh username@ip_address

Here is described how to get values needed for SSH connection:
- **ip_address** - In order to get the ip_address values for both created VMs we need to use the Terraform outputs called 'public_ip_address_vm_1' and 'public_ip_address_vm_2'. They will be printed in the terminal at the end of executing the 'terraform apply' command but we can also access them from Terraform outputs by using this command: 
	>terraform output
- **username**- The username value is the same as the one defined in the terraform.tfvars file for the vm_username variable.

The ssh_path variable specifies where on our local computer the private key will be saved. The recommended one for Windows is C:\\Users\\username\\.ssh\\id_rsa. 

For generating SSH keys we are using the modules/ssh module. We create two SSH key pairs for connection:
- Between our local computer and both VMs 
- From one VM to another (what is needed for Hadoop)

That module generates SSH keys as strings which we can save on our local computer and created VMs.

## Hadoop setup (new)
We are setting up Hadoop on two VMs:
- **VM1** - Which acts as a master node
- **VM2** - Which acts as a slave node

We are setting up Hadoop by executing bash scripts on both VMs which will download and configure all the necessary files, set up passwordless SSH connection from one VM (master node) to another (slave node) and created all the necessary folders and grant proper permissions to the hadoop user.

At first we are using the azurerm_virtual_machine_extension Terraform resource which uses Azure VM Extension in order to run a bash script on both VMs which sets up a passwordless SSH connection from VM1 (master node) to VM2 (slave node) and configure Hadoop files on VM1.

Then we can start the hadoop cluster.

### SSH setup
We need to have:
- SSH private key saved on VM1
- SSH public key added to the authorized_keys on both VM1 and VM2

Hadoop needs to be able to connect from VM1 through SSH to the localhost and also to VM2.

### Hadoop config files setup
We are executing two bash scripts from the bash_scripts folder using the azurerm_virtual_machine_extension Terraform resource:
- **vm1/configure_hadoop.tftpl** - It is executed on the VM1. It performs the following actions:
	- Edit /etc/hosts file - It assigns the hostnames of both VMs specified by the Terraform variable hostnames to the private IP addresses of both VMs.
	- Save the SSH private key - That key was generated by Terraform. It will be used for connection from VM1 to VM2.
	- Add the SSH public key to the authorized_keys - That is the key matching the private key mentioned in the previous step. \
		It will be used for connecting from VM1 to the localhost.
	- Install Java
	- Download Hadoop files
	- Modify .bashrc file - Specify there proper environment variables required by Hadoop.
	- Modify Hadoop files:
		- Hadoop-env.sh
		- core-site.xml
		- hdfs-site.xml
		- yarn-site.xml
		- hadoop/etc/hadoop/masters
		- hadoop/etc/hadoop/workers
	- Create required folders and assign proper permissions to the hadoop user for those folders - That's needed because Hadoop will be using the \
		Hadoop user in order to modify those folders. Hadoop user is a user which is running Hadoop commands (in our case specified by the vm_username \
		Terraform variable).
- **vm2/configure_hadoop.tftpl** - It is executed on the VM2. It performs almost the same actions as the script executed on the VM1. \
The only differences are as follows:
	- We don't save here the SSH private key. We only add the public key to the authorized keys so the VM1 can connect to the VM2.
	- In the hdfs-site.xml file instead of adding the dfs.namenode.name.dir property we are adding the dfs.datanode.data.dir. That's because \
		We want to run a name node on the master node and data node on the slave node.
	- We don't create the masters and workers files.
	- We create and assing permissions to different folders.
