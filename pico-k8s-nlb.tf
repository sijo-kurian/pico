# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# We would be creating a Network Load Balancer for high availability for the Kubernetes Master nodes. We would place
# our primary and backup control plane nodes behind this NLB
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the NLB for the control plane. This would be placed on two AZ's for higher availability
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_lb" "pico-k8s-nlb" {
  name               = "pico-k8s-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public-subnet[*].id

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }

  depends_on = [
    aws_vpc.eks-vpc,
    aws_lb_target_group.pico-k8s-tg
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the listerners for the NLB
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_lb_listener" "pico-k8s-nlb-listener" {
  load_balancer_arn       = aws_lb.pico-k8s-nlb.arn
  for_each = var.nlb_forwarding_config
      port                = each.key
      protocol            = each.value
      default_action {
        target_group_arn = aws_lb_target_group.pico-k8s-tg[each.key].arn
        type             = "forward"
      }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the Target group to use in the NLB
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_lb_target_group" "pico-k8s-tg" {
  for_each = var.nlb_forwarding_config
    name                  = "${lookup(var.tg_config, "name")}-${each.key}"
    port                  = each.key
    protocol              = each.value
  vpc_id                  = aws_vpc.eks-vpc.id
  target_type             = lookup(var.tg_config, "target_type")
  deregistration_delay    = 90
health_check {
    interval            = 30
    port                = each.value != "TCP_UDP" ? each.key : 80
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  tags = {
    Environment = var.cluster_name
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the attachment of primary to the TG
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_lb_target_group_attachment" "pico-k8s-tg-attachment-1" {
    
  for_each = var.nlb_forwarding_config
    target_group_arn  = aws_lb_target_group.pico-k8s-tg[each.key].arn
    port              = each.key
  target_id           = aws_instance.pico-k8s-master-1.id

    depends_on = [
    aws_vpc.eks-vpc,
    aws_lb_target_group.pico-k8s-tg
  ]                    
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Creating the attachment of backup to the TG
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "aws_lb_target_group_attachment" "pico-k8s-tg-attachment-2" {
    
  for_each = var.nlb_forwarding_config
    target_group_arn  = aws_lb_target_group.pico-k8s-tg[each.key].arn
    port              = each.key
  target_id           = aws_instance.pico-k8s-master-2.id

  depends_on = [
    aws_vpc.eks-vpc,
    aws_lb_target_group.pico-k8s-tg
  ]                        
}
