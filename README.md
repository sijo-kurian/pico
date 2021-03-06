# Multi Master Kubernetes Cluster on AWS

We be creating a two master kubernetes cluster with two worker nodes. 

Infrastructure required for the setup would be provisioned with the terraform plans. All the components like VPC, Subnets, Internet Gateway (IGW), NAT Gateways, Network Load Balancer, routing table, IAM Roles etc would be created in this plan.

Cluster nodes would be placed in a private subnet and would be accessed via a Network Load Balancer (NLB) configured in the public subnets. We will be provisioning a management server which act as the management node for access and configuring the cluster nodes.

Detailed architecture diagram is provided below.


![image](https://user-images.githubusercontent.com/55138596/114775669-77162900-9d69-11eb-8656-5cb67e8026c5.png)




## Pre-requisites

#### 1. Install Terraform
Installing Terraform is done by simply downloading the Terraform binary for your target platform from the Terraform website and moving it to any directory in your PATH.


#### 2. Configure AWS credentials

Terraform needs to have access to the AWS Access Key ID and AWS Secret Access Key of your AWS account in order to create AWS resources.

You can achieve this in one of the two following ways:

Create an ~/.aws/credentials file. This is automatically done for you if you configure the AWS CLI:

aws configure
Set the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables to your Access Key ID and Secret Access Key:

export AWS_ACCESS_KEY_ID=<AccessKeyID>
export AWS_SECRET_ACCESS_KEY=<SecretAccessKey>

#### 3. Create an SSH-Key Pair for the AWS EC2 Instances and a key pair for the Ansible playbooks

We are using two pairs of keys for the installation. EC2 instances are provisioned with a key pair called eu-west1-keypair and created another key pair specifically for 
running Ansible Playbooks. We would be using the management node as the Ansible Deployer and all the Kuberenetes (worker and master) nodes would be having the public key of the 
Ansible work inside.

You can update the key names with your key names in variables file. 


If you currently don't have this key pair on your system, you can generate it by running:

ssh-keygen
Note that ~/.ssh/id_rsa and ~/.ssh/id_rsa.pub are just default values and you can specify a different key pair to the module (with the private_key_file and public_key_file variables).

For example, you can generate a dedicated key pair for your cluster with:

ssh-keygen -f MyKeyPair
Which creates two files named MyKeyPair (private key) and MyKeyPair.pub (public key), which you can then specify to the corresponding input variables of the module.

## Installation

Installation would be done in two stages. In the initial stage we would be provisioning all the AWS Infrastructure required. Second stage would be on the management node using an installation script.
##### Versions Used: 
   ###### AWS Provider: v3.36.0
   ###### Terraform: v0.14.9

### AWS Infastructure Provision

#### 1. Initialize the plan
```sh
 $ terraform init
 ```

#### 2. Create the plan
```sh
 $ terraform plan
 ```
#### 3. Apply the plan
```sh
 $ terraform apply 
 ```
 You would be getting the management IP as an output from the terraform apply.
 
 ### Kubernetes Cluster Creation
 
 Log in to the management system using the EC2 key. This would be the node you would be using to manage and deploy Kuberenetes environment.
 
 Transfer the ansible private key to this server. This could be automated, how ever that would leave the private key in Terraform environment. For security reasons its ideal to keep the private key outside terraform or use any vault solutions like AWS KMS.
 
 once you places the export the ansible private key location as an environment variable
 
 ```sh
 export ANSIBLE_KEY_FILE=<fullpath to the key file>
 ```
 Now change the directory to /tmp/ansible-work, terraform build stage would have copied the necessary scripts and files to this location. You should be able to run the install script from this location. This script will install the cluster components on two servers and configure two worker nodes to join them. Network CNI plugin and AWS native storage class also would be installed.
 
 ```sh
 # cd /tmp/ansible-work; ./install_kubeadm.sh
 ```
 
 Install process will configure the kuberenetes context also in the management server. So you could check the nodes in the Kubernetes cluster from here
 
 ```sh
 # kubectl get nodes
 ```
 
## Sample Application

I have used a small hello world application to demonstrate deploying to the Kuberenetes cluster via GitLabs CI

Link to the application repo : https://github.com/sijo-kurian/hello-world-k8s

---




