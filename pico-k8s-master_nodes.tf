# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# We would be creating two master nodes for high availability and redundancy
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the IAM role for the cluster nodes
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_iam_role" "pico-k8s_cluster" {
  name = var.cluster_name
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "pico-k8s-cluster" {
  name        = var.cluster_name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyVolume",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeVpcs",
        "elasticloadbalancing:*",
        "iam:CreateServiceLinkedRole",
        "kms:DescribeKey"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
})
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the policy attachment for the master nodes
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_iam_role_policy_attachment" "pico-k8s-cluster" {
  role      = aws_iam_role.pico-k8s_cluster.name
  policy_arn = aws_iam_policy.pico-k8s-cluster.arn
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating an instance profile for the master nodes
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_iam_instance_profile" "master-nodes" {
  name = "terraform-k8s-master"
  role = aws_iam_role.pico-k8s_cluster.name
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the Security group for master nodes. 
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_security_group" "pico-k8s-cluster-sg" {
  name        = "terraform-eks"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.eks-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the Security group for master nodes. We would be allowing SSH traffic from the mgmt Network. If we are 
# using an Elastic IP for mgmt, we can restrict the route only to mgmt
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


resource "aws_security_group_rule" "pico-k8s-cluster" {
  type                     = "ingress"
  description              = "Allow mgmt to reach on SSH"
  from_port                = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.pico-k8s-cluster-sg.id
  cidr_blocks = [
      aws_subnet.public-subnet[0].cidr_block,
      aws_subnet.public-subnet[1].cidr_block
    ]
  to_port                  = 22

}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the Security group rule to allow master nodes can be reached on API port from mgmt or any other management
# nodes in the public subnet
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


resource "aws_security_group_rule" "pico-k8s-cluster-api" {
  type                     = "ingress"
  description              = "Allow NLB to reach on 6443"
  protocol                 = "tcp"
  from_port                = 6443
  to_port                  = 6443
  security_group_id        = aws_security_group.pico-k8s-cluster-sg.id
  cidr_blocks = [
      aws_subnet.public-subnet[0].cidr_block,
      aws_subnet.public-subnet[1].cidr_block
    ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the Security group for master nodes. We would be allowing traffic from internal private subnets so that master
# and worker nodes can communicate each other. 
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


resource "aws_security_group_rule" "pico-k8s-cluster-internal" {
  type                     = "ingress"
  description              = "Allow master to communicate each other"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.pico-k8s-cluster-sg.id
  cidr_blocks = [
      aws_subnet.private-subnet[0].cidr_block,
      aws_subnet.private-subnet[1].cidr_block
    ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the Master nodes for the control plane
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


locals {
  vars = {
    control_plane_api = aws_lb.pico-k8s-nlb.dns_name
    ansible_ssh_key = file(var.ansible_public_key)
  }
}


resource "aws_instance" "pico-k8s-master-1" {
   depends_on = [
    aws_vpc.eks-vpc,
    aws_subnet.private-subnet[0],
    aws_security_group.pico-k8s-cluster-sg,
    aws_lb.pico-k8s-nlb
  ]
  ami = var.ami_id
  instance_type = "t2.medium"
  subnet_id = aws_subnet.private-subnet[0].id
  iam_instance_profile        = aws_iam_instance_profile.master-nodes.name

  # Keyname and security group are obtained from the reference of their instances created above!
  key_name = var.key-pair
   
  # Security group ID's
  security_groups             = [aws_security_group.pico-k8s-cluster-sg.id]

  tags = {
     "Name"                                      = "pico-k8s-master-1"
     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
   }
user_data = templatefile("pico-k8s_nodes_user_data.sh", local.vars)

}


resource "aws_instance" "pico-k8s-master-2" {
   depends_on = [
    aws_vpc.eks-vpc,
    aws_subnet.private-subnet[1],
    aws_security_group.pico-k8s-cluster-sg,
    aws_lb.pico-k8s-nlb
  ]
  ami = var.ami_id
  instance_type = "t2.medium"
  subnet_id = aws_subnet.private-subnet[1].id
  iam_instance_profile        = aws_iam_instance_profile.master-nodes.name
 
   # Keyname and security group are obtained from the reference of their instances created above!
  key_name = var.key-pair
   
  # Security group ID's
  security_groups             = [aws_security_group.pico-k8s-cluster-sg.id]

  tags = {
     "Name"                                      = "pico-k8s-master-2"
     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
   }

   user_data = templatefile("pico-k8s_nodes_user_data.sh", local.vars)
}


