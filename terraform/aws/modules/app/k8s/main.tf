resource "aws_vpc" "tom_vpc" {
  cidr_block = "10.20.0.0/16"

  tags = merge(var.tags, {
    Name = "vpc_${var.name}"
  })
}


resource "aws_internet_gateway" "tom_igw" {
  vpc_id = aws_vpc.tom_vpc.id

  tags = merge(var.tags, {
    Name = "igw_${var.name}"
  })
}

resource "aws_subnet" "tom_subnet" {
  vpc_id            = aws_vpc.tom_vpc.id
  cidr_block        = "10.20.1.0/24"
  availability_zone = "us-west-2a"

  tags = merge(var.tags, {
    Name = "subnet_${var.name}"
  })
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.tom_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tom_igw.id
  }
}

resource "aws_route_table_association" "tom_rta" {
  subnet_id      = aws_subnet.tom_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "sg" {
  name   = "sg_${var.name}"
  vpc_id = aws_vpc.tom_vpc.id

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

  tags = merge(var.tags, {
    Name = "${var.name}-controller"
  })
}


resource "aws_instance" "workers" {
  ami                         = var.worker_ami
  instance_type               = var.worker_size
  count                       = var.worker_count
  associate_public_ip_address = true
  key_name                    = "ssh-key_${var.name}"
  user_data                   = <<-EOF
    #!/bin/bash
    mkdir -p /etc/ansible/facts.d
    printf '[kubernetes]\nmode=worker\ncontroller_ip=${aws_instance.controller.public_ip}\n' >/etc/ansible/facts.d/aws.fact
  EOF

  vpc_security_group_ids = [aws_security_group.sg.id]

  tags = merge(var.tags, {
    Name = "${var.name}-worker-${count.index}"
  })
}


data "aws_subnet_ids" "subnets" {
  vpc_id = aws_vpc.tom_vpc.id
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
  port                          = var.target_port
  protocol                      = "HTTP"
  vpc_id                        = aws_vpc.tom_vpc.id

  tags = merge(var.tags, {
    Name = "${var.name}-tg"
  })
}


resource "aws_lb_target_group_attachment" "attachment" {
  count            = length(aws_instance.workers)
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.workers[count.index].id
  port             = var.target_port
}


resource "aws_route53_record" "www" {
  zone_id = var.zone_id
  name    = var.ingress_dns
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.lb.dns_name]
}
