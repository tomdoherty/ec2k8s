data "aws_vpc" "default" {
  default = true
}


data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}


resource "aws_security_group" "sg" {
  name   = "sg_${var.name}"
  vpc_id = data.aws_vpc.default.id

  tags = merge(var.tags, {
    Name = "sg_${var.name}"
  })
}


resource "aws_security_group_rule" "ingress_tcp" {
  for_each          = var.tcp_ingress_ports
  description       = "TCP ingress for port ${each.key}"
  type              = "ingress"
  from_port         = each.key
  to_port           = each.key
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}


resource "aws_security_group_rule" "ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.sg.id
}


resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}


resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key_${var.name}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9FNpoDiJLd+if9noTjimmiCfTi0BUa3uQFnUOf5PVLx+gT0+61j7+EOvvqdVN8pUI/+eNMJPqDvrPsKqe63QJkDboltJaY9m39KAPAVw/L8myLDsxcXprmLOtK8MlHc1FvGwsUeiZAZaEdt/KfOd/zkU/qd5xpQVk9ERO/H+o3T5ReuEV63vlSnF8mXvh5gFzJVLiTgMgGhYizg24Z894nalGx+rvPz1XWVhEqlZsQsdyXQsnUdoboSyVw1tcN3y87Tws8k72ZRMd5Yc9zs+5XN3Yj4DOtJzac0wvcFAVIetHMz2BWUbT5Ei9BDAjGerI+nr47p5CDetyqy82Ctwz tom@Thomass-MacBook-Pro.local"

  tags = merge(var.tags, {
    Name = "ssh-key_${var.name}"
  })
}


resource "aws_instance" "controller" {
  ami                         = "ami-08d70e59c07c61a3a"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "ssh-key_${var.name}"
  user_data                   = <<-EOF
    #!/bin/bash
    mkdir -p /etc/ansible/facts.d
    printf '[kubernetes]\nmode=controller\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [
    aws_security_group.sg.id
  ]

  tags = merge(var.tags, {
    Name = "${var.name}-controller"
  })
}


resource "aws_instance" "workers" {
  ami                         = "ami-08d70e59c07c61a3a"
  instance_type               = "t2.micro"
  count                       = var.worker_count
  associate_public_ip_address = true
  key_name                    = "ssh-key_${var.name}"
  user_data                   = <<-EOF
    #!/bin/bash
    mkdir -p /etc/ansible/facts.d
    printf '[kubernetes]\nmode=worker\ncontroller_ip=${aws_instance.controller.public_ip}\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [
    aws_security_group.sg.id
  ]

  tags = merge(var.tags, {
    Name = "${var.name}-worker-${count.index}"
  })
}


data "aws_subnet_ids" "subnets" {
  vpc_id = data.aws_vpc.default.id
}


resource "aws_lb" "lb" {
  name               = "${var.name}-alb"
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = data.aws_subnet_ids.subnets.ids

  tags = merge(var.tags, {
    Name = "${var.name}-alb"
  })
}


resource "aws_alb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}


resource "aws_lb_target_group" "tg" {
  load_balancing_algorithm_type = "round_robin"
  name                          = "${var.name}-tg"
  port                          = 30171
  protocol                      = "HTTP"
  vpc_id                        = data.aws_vpc.default.id

  tags = merge(var.tags, {
    Name = "${var.name}-tg"
  })
}


resource "aws_lb_target_group_attachment" "attachment" {
  count            = length(aws_instance.workers)
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.workers[count.index].id
  port             = 30171
}


resource "aws_route53_record" "www" {
  zone_id = var.zone_id
  name    = var.ingress_dns
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.lb.dns_name]
}
