resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "vpc_${var.name}"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(var.tags, {
    Name = "igw_${var.name}"
  })
}

resource "aws_subnet" "subnet_public" {
  count             = length(var.vpc_subnet_public_cidrs)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = element(var.vpc_availability_zones, count.index)
  cidr_block        = element(var.vpc_subnet_public_cidrs, count.index)

  map_public_ip_on_launch = "true"

  tags = merge(var.tags, {
    Name = "subnet_${var.name}"
  })
}

resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(var.tags, {
    Name = "rtb_${var.name}"
  })
}

resource "aws_route_table_association" "rta_subnet_public" {
  count          = length(var.vpc_subnet_public_cidrs)
  subnet_id      = element(aws_subnet.subnet_public.*.id, count.index)
  route_table_id = aws_route_table.rtb_public.id
}


resource "aws_security_group" "sg" {
  name   = "sg_${var.name}"
  vpc_id = aws_vpc.vpc.id

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
  subnet_id              = aws_subnet.subnet_public.0.id

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
  subnet_id              = aws_subnet.subnet_public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-worker-${count.index}"
  })
}


resource "aws_lb" "lb" {
  name               = "${var.name}-alb"
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = aws_subnet.subnet_public.*.id

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
  vpc_id                        = aws_vpc.vpc.id

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
