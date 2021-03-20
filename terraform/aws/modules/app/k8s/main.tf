resource "aws_security_group" "sg" {
  name   = "sg_${var.name}"
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "sg_${var.name}"
  })
}


// XXX switch to looping through dict so can attach proper description
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
  public_key = var.ssh_public_key

  tags = merge(var.tags, {
    Name = "ssh-key_${var.name}"
  })
}


resource "aws_instance" "controller" {
  ami                         = var.worker_ami
  instance_type               = var.controller_size
  associate_public_ip_address = true
  key_name                    = "ssh-key_${var.name}"
  user_data                   = <<-EOF
    #!/bin/bash
    mkdir -p /etc/ansible/facts.d
    printf '[kubernetes]\nmode=controller\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = var.sn_public_ids.0

  tags = merge(var.tags, {
    Name = "${var.name}-controller"
  })
}


resource "aws_instance" "workers" {
  for_each                    = { for x in range(var.worker_count) : x => "worker-${x}" }
  ami                         = var.worker_ami
  instance_type               = var.worker_size
  associate_public_ip_address = true
  key_name                    = "ssh-key_${var.name}"
  user_data                   = <<-EOF
    #!/bin/bash
    mkdir -p /etc/ansible/facts.d
    printf '[kubernetes]\nmode=worker\ncontroller_ip=${aws_instance.controller.public_ip}\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = element(var.sn_public_ids, each.key)

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value}"
  })
}


resource "aws_lb" "lb" {
  name               = "${var.name}-alb"
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = var.sn_public_ids

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
  port                          = var.target_port
  protocol                      = "HTTP"
  vpc_id                        = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-tg"
  })
}


resource "aws_lb_target_group_attachment" "attachment" {
  for_each         = { for x in range(var.worker_count) : x => "worker-${x}" }
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.workers[each.key].id
  port             = var.target_port
}


resource "aws_route53_record" "www" {
  zone_id = var.zone_id
  name    = var.ingress_dns
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.lb.dns_name]
}
