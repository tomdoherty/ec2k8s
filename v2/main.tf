
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment#example-usage
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
// https://github.com/chrisshiels/terraform/blob/master/modules/aws/vpc/main.tf
// https://v1-18.docs.kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#token-based-discovery-without-ca-pinning

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "k8s-sg" {
  name   = "k8s-security-group"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ingress_30171" {
  type              = "ingress"
  from_port         = 30171
  to_port           = 30171
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-sg.id
}

resource "aws_security_group_rule" "ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-sg.id
}

resource "aws_security_group_rule" "ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.k8s-sg.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-sg.id
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9FNpoDiJLd+if9noTjimmiCfTi0BUa3uQFnUOf5PVLx+gT0+61j7+EOvvqdVN8pUI/+eNMJPqDvrPsKqe63QJkDboltJaY9m39KAPAVw/L8myLDsxcXprmLOtK8MlHc1FvGwsUeiZAZaEdt/KfOd/zkU/qd5xpQVk9ERO/H+o3T5ReuEV63vlSnF8mXvh5gFzJVLiTgMgGhYizg24Z894nalGx+rvPz1XWVhEqlZsQsdyXQsnUdoboSyVw1tcN3y87Tws8k72ZRMd5Yc9zs+5XN3Yj4DOtJzac0wvcFAVIetHMz2BWUbT5Ei9BDAjGerI+nr47p5CDetyqy82Ctwz tom@Thomass-MacBook-Pro.local"
}

resource "aws_instance" "controller" {
  ami                         = "ami-08d70e59c07c61a3a"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "ssh-key"
  user_data                   = <<-EOF
    #!/bin/bash
    mkdir -p /etc/ansible/facts.d
    printf '[kubernetes]\nmode=controller\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [
    aws_security_group.k8s-sg.id
  ]
}

resource "aws_instance" "workers" {
  ami                         = "ami-08d70e59c07c61a3a"
  instance_type               = "t2.micro"
  count                       = 3
  associate_public_ip_address = true
  key_name                    = "ssh-key"
  user_data                   = <<-EOF
    #!/bin/bash
    mkdir -p /etc/ansible/facts.d
    printf '[kubernetes]\nmode=worker\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [
    aws_security_group.k8s-sg.id
  ]
}

resource "aws_lb" "lb" {
  name               = "k8s-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnet_ids.default.ids
}

resource "aws_lb_target_group" "agent-30171" {
  port     = 30171
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.agent-30171.arn
  target_id        = aws_instance.controller.id
  port             = 30171
}

resource "aws_lb_listener" "port_30171" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "30171"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent-30171.arn
  }
}

resource "aws_route53_zone" "primary" {
  name = "tom.works"
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "k8s.tom.works"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.lb.dns_name]
}
