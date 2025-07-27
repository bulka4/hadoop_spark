# Introduction
In this repository we have:
- Terraform scripts for creating Linux VMs in Azure.
- Bash scripts for setting up Hadoop, Spark and Jupyter Notebook on those VMs. 

We will create two Linux VMs, called VM1 and VM2. VM1 will act as a master and VM2 as a slave node.



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

## Connecting to the created VMs from our local computer through SSH
The Terraform code will generate SSH keys pair, save the private key on our local computer and add the public key to the authorized keys on the created VMs.

Then we can connect to the created VMs by using this command on our local computer:
>ssh username@ip_address

Here is described how to get values needed for SSH connection:
- **ip_address** - In order to get the ip_address values for both created VMs we need to use the Terraform outputs called 'public_ip_address_vm_1' and 'public_ip_address_vm_2'. More info about those outputs in the 'Terraform outputs' section of this documentation.
- **username**- The username value is the same as the one defined in the terraform.tfvars file for the vm_username variable.

The ssh_path Terraform variable specifies where on our local computer the private key will be saved. The recommended one for Windows is C:\\Users\\username\\.ssh\\id_rsa (if we save the private key here then we don't need to provide a path to that key when running the 'ssh' command).

We are using the modules/ssh module which generates SSH keys as strings which are saved on our local computer and created VMs.

## Starting Hadoop and Spark cluster
In order to start the Hadoop and Spark cluster we need to connect through SSH to the VM1 which acts as a master node and run the following commands:
- $HADOOP_HOME/bin/hdfs namenode -format # We need to run this only when starting Hadoop cluster for the first time. If we run this later on it will remove all the data from the cluster.
- $HADOOP_HOME/sbin/start-dfs.sh # Start HDFS
- $HADOOP_HOME/sbin/start-yarn.sh # Start YARN
- $SPARK_HOME/sbin/start-all.sh # Start Spark

In order to learn about how to connect to that VM through SSH reference to the 'Connecting to the created VMs from our local computer through SSH' section below in this documentation.

## Accessing Jupyter Notebook
Jupyter Notebook will be started on the VM1 by executing a bash script by Terraform. To access the Jupyter Notebook from Spark use the URL:
>public_ip_address_vm_1:8888

Where public_ip_address_vm_1 is the Terraform output. More information about how to get this output is in the 'Terraform outputs' section of this documentation.

We also need to provide a password when logging into Jupyter Notebook. It is specified by the Terraform variable jupyter_notebook_password ('admin' by default).

## Starting Spark session
Once we are in the Jupyter Notebook, we can create a Spark session in the following way:

```
from pyspark.sql import SparkSession
spark = SparkSession.builder \
    .appName("MySparkApp") \
    .master("spark://hadoopmaster:7077") \ # hadoopmaster in a hostname of the Spark Master Node.
    .getOrCreate()
```

## Accessing HDFS
To browse HDFS files we need to use this URL:
>public_ip_address_vm_1:9870

Where public_ip_address_vm_1 is the Terraform output. More information about how to get this output is in the 'Terraform outputs' section of this documentation.



# Prerequisites
## Terraform variables
Before using this code we need to create terraform.tfvars file which look like terraform-draft.tfvars file in the same location. It is described there what values to provide. We are assigning there values to variables from the variables.tf file located in the same folder. In the variables.tf we can also find descriptions of those variables. We need to assign values only for those variables which doesn't have assigned the default value.

## Terraform configuration
We need to configure properly Terraform on our computer so it can create resources in our Azure subscription, it is described here: [developer.hashicorp.com](https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-build).

## Azure subscription
We need to have a subscription on the Azure platform portal.azure.com.



# Code description
In the below sections we can find more details about how the code works.

## Creating Azure resources with Terraform
In the terraform_linux_vm folder we have terraform code which creates our VMs and configures on them Spark and Kubernetes by executing bash scripts on them. We have there the main.tf file which creates all the resources. That file uses modules defined in the terraform_linux_vm > modules folder. Each module is dedicated to creating one type of resource in Azure.

### Terraform outputs
Terraform creates two outputs: 'public_ip_address_vm_1' and 'public_ip_address_vm_2'. They are printed at the end of executing 'terraform apply' and they can be accessed by running the command:
>terraform output

### Executing bash scripts on VMs
After creating VMs using Terraform we are executing on them bash scripts using the azurerm_virtual_machine_extension Terraform resource which uses Azure VM Extension.

Those bash scripts are used to configure both VMs for running Hadoop. They can't be used on their own on a Linux machine since they are rendered using the Terraform templatefile function first before execution. More information about that here [developer.hashicorp.com](https://developer.hashicorp.com/terraform/language/functions/templatefile).

We are inserting into those scripts variables specified in the templatefile function (what can be found in the terraform_linux_vm > main.tf script) and also we are using there escape sequences. More information about that here [developer.hashicorp.com](https://developer.hashicorp.com/terraform/language/expressions/strings).

### Network security rules
For our VMs we are creating a Network security group in which we defines security rules. Those rules specifies how our VMs can be accessed. They are defined in the modules > networks > main.tf file in the azurerm_network_security_group resource.

In every security rule we allow for inbound traffic using TCP for specific ports. That will allow us to access from our local computer different websites generated by Hadoop, Spark and Jupyter.

## Hadoop setup
We are setting up Hadoop on two VMs:
- **VM1** - Which acts as a master node
- **VM2** - Which acts as a slave node

On both VMs we are creating a Hadoop user (with username specified by the vm_username Terraform variable) which will be executing Hadoop commands and which will have proper permissions to folders.

We are setting up Hadoop by executing bash scripts on both VMs (using the azurerm_virtual_machine_extension) which will download and configure all the necessary files, set up passwordless SSH connection from one VM (master node) to another (slave node) and create all the necessary folders, and grant proper permissions to the Hadoop user for those folders.

Then we can start manually the hadoop cluster as described earlier in the 'Repository guide > Starting Hadoop cluster' section of this documentation.

### Hadoop processes
Below is described which processes we will be running on which nodes.

Processes running on the Master Node:
- SecondaryNameNode
- ResourceManager
- NameNode

Processes running on the Slave Node:
- DataNode
- NodeManager

### SSH setup
We need to have:
- SSH private key saved on VM1
- SSH public key added to the authorized_keys on both VM1 and VM2

Hadoop needs to be able to connect from VM1 through SSH to the localhost and also to VM2. That SSH key pair will be generated by Terraform. Then on both VMs we will execute bash scripts (using the azurerm_virtual_machine_extension) which will save the private key on the VM1 and add the public key to the authorized keys on both VMs.

### Hadoop config files setup
We are executing two bash scripts from the bash_scripts folder (using the azurerm_virtual_machine_extension):
- **vm1/configure_hadoop.tftpl** - It is executed on the VM1. It performs the following actions:
	- Edit /etc/hosts file - It assigns the hostnames of both VMs specified by the Terraform variable hostnames to the private IP addresses of both VMs.
	- Save the SSH private key - That key was generated by Terraform. It will be used for connection from VM1 to VM2.
	- Add the SSH public key to the authorized_keys - That is the key matching the private key mentioned in the previous step. It will be used for connecting from VM1 to the localhost.
	- Install Java
	- Download Hadoop and Spark files
	- Modify .bashrc file - Specify there proper environment variables required by Hadoop and Spark.
	- Modify Hadoop and Spark files:
		- hadoop-env.sh, yarn-env.sh and spark-env.sh
		- core-site.xml
		- hdfs-site.xml
		- yarn-site.xml
		- $HADOOP_HOME/etc/hadoop/masters
		- $HADOOP_HOME/etc/hadoop/workers
		- $SPARK_HOME/conf/workers
	- Create required folders and assign proper permissions to the Hadoop user for those folders - That's needed because Hadoop will be using the Hadoop user in order to modify
		those folders.
	- Set up and run Jupyter Notebook.
- **vm2/configure_hadoop.tftpl** - It is executed on the VM2. It performs almost the same actions as the script executed on the VM1. The only differences are as follows:
	- We don't save here the SSH private key. We only add the public key to the authorized keys so the VM1 can connect to the VM2 (we don't the VM2 to connect to the VM1).
	- In the .bashrc we don't specify the HADOOP_CONF_DIR env variable (which is needed to run Spark shell from the master node.)
	- In the hdfs-site.xml file instead of adding the dfs.namenode.name.dir property we are adding the dfs.datanode.data.dir. That's because We want to run a name node process 
		only on the master node and a data node process only on the slave node.
	- We don't create the masters and workers files.
	- We create and assing permissions to different folders.
