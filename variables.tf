# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Variables used across the infrastructure creation
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

variable "cluster_name" {
  default = "pico-k8s-cluster"
  type = string
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
  type = string
}

variable "key-pair" {
  default = "eu-west-1-keypair"
}


variable "tg_config" {
  default = {
    target_type = "instance"
    health_check_protocol  = "TCP"
    name  = "pico-k8s-cluster"
  }
}

variable "tg_config_instance" {
  default = 2
}

variable "nlb_forwarding_config" {
  default = {
      6443        =   "TCP"
  }
}

variable "backend_s3_bucket" {
  default = "terraform-remote-state-pico-s3"
}

variable "backend_dynamo" {
  default = "terraform-state-lock-dynamo"
}


variable "ami_id" {
  default = "ami-03c4a26550b802f69"
}

variable "mgmt_private_key" {
  default = "eu-west-1-keypair.pem"
}

variable "ansible_public_key" {
  default = "MyKeyPair.pub"
}