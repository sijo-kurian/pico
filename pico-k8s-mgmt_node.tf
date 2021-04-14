# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create a security group for the mgmt host
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


resource "aws_security_group" "mgmt-sg" {
  name   = "mgmt-security-group"
  vpc_id = aws_vpc.eks-vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_vpc.eks-vpc
  ]
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create the mgmt host and place it in the public subnet
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

locals {
  inventory = {
    master1_ip = aws_instance.pico-k8s-master-1.private_ip
    master2_ip = aws_instance.pico-k8s-master-2.private_ip
    worker1_ip = aws_instance.pico-k8s-worker[0].private_ip
    worker2_ip = aws_instance.pico-k8s-worker[1].private_ip
    nlb_dns_name = aws_lb.pico-k8s-nlb.dns_name
  }
}

resource "aws_instance" "pico-k8s-mgmt" {
   depends_on = [
    aws_vpc.eks-vpc,
    aws_subnet.public-subnet[0]
  ]
  
  ami = var.ami_id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public-subnet[0].id
  associate_public_ip_address = true

  # Keyname and security group are obtained from the reference of their instances created above!
  key_name = var.key-pair
   
  # Security group ID's
  security_groups             = [aws_security_group.mgmt-sg.id]
  tags = {
   Name = "pico-k8s-mgmt"
  }
  user_data = templatefile("pico-k8s-mgmt_user_data.sh", local.inventory)

}

resource "null_resource" "copy_playbooks" {

  provisioner "file" {
    source      = "./ansible-work"
    destination = "/tmp"

    connection {
      host = aws_instance.pico-k8s-mgmt.public_ip
      user = "ubuntu"
      private_key = file(var.mgmt_private_key)
    }
}
}

output "management_ip" {
  value = aws_instance.pico-k8s-mgmt.public_ip
}



