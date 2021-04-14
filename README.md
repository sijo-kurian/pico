# Multi Master Kubernetes Cluster on AWS

We would be creating a two master kubernetes cluster with two worker nodes. 

Infrastructure required for the setup would be provisioned with the terraform plans. All the components like VPC, Subnets, Internet Gateway (IGW), NAT Gateways, Network Load Balancer, routing table, IAM Roles etc would be created in this plan.

Cluster nodes would be placed in a private subnet and would be accessed via a Network Load Balancer (NLB) configured in the public subnets. We will be provisioning a management server which act as the management node for access and configuring the cluster nodes.

Detailed architecture diagram is provided below.

![image](https://user-images.githubusercontent.com/55138596/114378806-fa742680-9b7f-11eb-95f2-cf2a43fe3704.png)

---




