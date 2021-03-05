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

resource "aws_security_group_rule" "ingress_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-sg.id
}

resource "aws_security_group_rule" "ingress_6443" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s-sg.id
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
    printf '[kubernetes]\nmode=worker\ncontroller_ip=${aws_instance.controller.public_ip}\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [
    aws_security_group.k8s-sg.id
  ]
}

resource "aws_elb" "lb" {
  name               = "k8s-lb"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  listener {
    instance_port     = 30171
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:30171"
    interval            = 5
  }

  instances           = aws_instance.workers.*.id
}

data "aws_route53_zone" "primary" {
  name = "tom.works"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "k8s.tom.works"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_elb.lb.dns_name]
}
