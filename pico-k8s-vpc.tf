# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Get the details of available AZ's
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

data "aws_availability_zones" "available" {
  
}

resource "aws_vpc" "eks-vpc" {
  cidr_block = var.vpc_cidr

  tags = {
      Name = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# We would be creating two Public Subnets in different AZ's for availability
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_subnet" "public-subnet" {
   count = 2
   availability_zone = data.aws_availability_zones.available.names[count.index]
   cidr_block        = "10.0.${count.index+1}.0/24"
   vpc_id            = aws_vpc.eks-vpc.id
   tags = {
     "Name"                                      = "public-subnet-${count.index}"
     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
   }
 }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create an internet gateway to attach to the VPC
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_internet_gateway" "eks-igw" {
   vpc_id = aws_vpc.eks-vpc.id
   tags = {
     Name = "terraform-eks-igw"
   }
 }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create a routing table for the public subnets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_route_table" "eks-public-rt" {
   vpc_id = aws_vpc.eks-vpc.id
   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.eks-igw.id
   }
 }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Assosiate the routing table to the public subnets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_route_table_association" "eks-rt-attachment" {
   count = 2
   subnet_id      = aws_subnet.public-subnet[count.index].id
   route_table_id = aws_route_table.eks-public-rt.id
 }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# We would be creating two private Subnets in different AZ's for availability. This is where we would be placing the
# kuberenets cluster and worker nodes
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_subnet" "private-subnet" {
   count = 2
   availability_zone = data.aws_availability_zones.available.names[count.index]
   cidr_block        = "10.0.1${count.index}.0/24"
   vpc_id            = aws_vpc.eks-vpc.id
   tags = {
     "Name"                                      = "private-subnet-${count.index}"
     "kubernetes.io/cluster/${var.cluster_name}" = "owned"
   }
 }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating an Elastic IP for the NAT GW1
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_eip" "pico-k8s-nat-gw-eip-1" {
  depends_on = [
    aws_route_table_association.eks-rt-attachment
  ]
  vpc = true
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating a NAT gateway so that kubernetes nodes can reach outside for getting software's patches etc
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_nat_gateway" "pico-k8s-nat-gw-1" {
  depends_on = [
    aws_eip.pico-k8s-nat-gw-eip-1
  ]

  # Allocating the Elastic IP to the NAT Gateway!
  allocation_id = aws_eip.pico-k8s-nat-gw-eip-1.id
  
  # Associating it in the Public Subnet!
  subnet_id = aws_subnet.public-subnet[0].id
  tags = {
    Name = "pico-k8s-ngw1"
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating an Elastic IP for the NAT GW2
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_eip" "pico-k8s-nat-gw-eip-2" {
  depends_on = [
    aws_route_table_association.eks-rt-attachment
  ]
  vpc = true
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating a NAT gateway so that kubernetes nodes can reach outside for getting software's patches etc
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_nat_gateway" "pico-k8s-nat-gw-2" {
  depends_on = [
    aws_eip.pico-k8s-nat-gw-eip-2
  ]

  # Allocating the Elastic IP to the NAT Gateway!
  allocation_id = aws_eip.pico-k8s-nat-gw-eip-2.id
  
  # Associating it in the Public Subnet!
  subnet_id = aws_subnet.public-subnet[1].id
  tags = {
    Name = "pico-k8s-ngw2"
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the routing table for the private subnet
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_route_table" "eks-private-rt-1" {
   vpc_id = aws_vpc.eks-vpc.id
   route {
     cidr_block = "0.0.0.0/0"
     nat_gateway_id = aws_nat_gateway.pico-k8s-nat-gw-1.id
   }
 }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the routing table for the private subnet
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
resource "aws_route_table" "eks-private-rt-2" {
   vpc_id = aws_vpc.eks-vpc.id
   route {
     cidr_block = "0.0.0.0/0"
     nat_gateway_id = aws_nat_gateway.pico-k8s-nat-gw-2.id
   }
 }

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Route table assosiation for the private subnets
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 resource "aws_route_table_association" "eks-private-rt-1" {
   subnet_id      = aws_subnet.private-subnet[0].id
   route_table_id = aws_route_table.eks-private-rt-1.id
 }

 resource "aws_route_table_association" "eks-private-rt-2" {
   subnet_id      = aws_subnet.private-subnet[1].id
   route_table_id = aws_route_table.eks-private-rt-2.id
 }
