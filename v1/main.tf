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

resource "random_password" "k3s_cluster_secret" {
  length  = 30
  special = false
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9FNpoDiJLd+if9noTjimmiCfTi0BUa3uQFnUOf5PVLx+gT0+61j7+EOvvqdVN8pUI/+eNMJPqDvrPsKqe63QJkDboltJaY9m39KAPAVw/L8myLDsxcXprmLOtK8MlHc1FvGwsUeiZAZaEdt/KfOd/zkU/qd5xpQVk9ERO/H+o3T5ReuEV63vlSnF8mXvh5gFzJVLiTgMgGhYizg24Z894nalGx+rvPz1XWVhEqlZsQsdyXQsnUdoboSyVw1tcN3y87Tws8k72ZRMd5Yc9zs+5XN3Yj4DOtJzac0wvcFAVIetHMz2BWUbT5Ei9BDAjGerI+nr47p5CDetyqy82Ctwz tom@Thomass-MacBook-Pro.local"
}

resource "aws_security_group" "k3s-ingress" {
  name   = "k3s-security-group"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s-ingress.id
}

resource "aws_security_group_rule" "ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s-ingress.id
}

resource "aws_security_group_rule" "ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s-ingress.id
}

resource "aws_security_group_rule" "ingress_k3s" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s-ingress.id
}

resource "aws_security_group_rule" "ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.k3s-ingress.id
}

resource "aws_security_group_rule" "ingress_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k3s-ingress.id
}

resource "aws_instance" "k3s-server" {
  ami                         = "ami-08d70e59c07c61a3a"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "ssh-key"

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /var/lib/rancher/k3s/server/manifests
              cat <<'EOY' >/var/lib/rancher/k3s/server/manifests/nginx.yaml
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                labels:
                  app: nginx
                name: nginx
              spec:
                replicas: 3
                selector:
                  matchLabels:
                    app: nginx
                strategy: {}
                template:
                  metadata:
                    labels:
                      app: nginx
                  spec:
                    initContainers:
                    - name: hello
                      image: busybox
                      command: ['sh', '-c', 'echo hello from $HOSTNAME >/usr/share/nginx/html/index.html']
                      volumeMounts:
                      - name: workdir
                        mountPath: /usr/share/nginx/html
                    containers:
                    - image: nginx
                      name: nginx
                      resources: {}
                      volumeMounts:
                      - name: workdir
                        mountPath: /usr/share/nginx/html
                    volumes:
                    - name: workdir
                      emptyDir: {}

              ---
              apiVersion: v1
              kind: Service
              metadata:
                labels:
                  app: nginx
                name: nginx
              spec:
                ports:
                - name: 80-80
                  port: 80
                  protocol: TCP
                  targetPort: 80
                selector:
                  app: nginx
                type: ClusterIP
              ---
              apiVersion: networking.k8s.io/v1
              kind: Ingress
              metadata:
                name: nginx
              spec:
                rules:
                - host: k3s.tom.works
                  http:
                    paths:
                    - backend:
                        service:
                          name: nginx
                          port:
                            number: 80
                      path: /
                      pathType: Exact
              EOY
              curl -sfL https://get.k3s.io | K3S_CLUSTER_SECRET="${random_password.k3s_cluster_secret.result}" sh -
              EOF


  vpc_security_group_ids = [
    aws_security_group.k3s-ingress.id
  ]
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
              #!/bin/bash
              curl -sfL https://get.k3s.io | K3S_URL="https://${aws_instance.k3s-server.public_ip}:6443" K3S_CLUSTER_SECRET="${random_password.k3s_cluster_secret.result}" sh -
              EOF

  }
}

resource "aws_launch_template" "k3s-agent" {
  name_prefix   = "k3s-agent"
  image_id      = "ami-08d70e59c07c61a3a"
  instance_type = "t2.micro"
  key_name      = "ssh-key"

  user_data = data.template_cloudinit_config.config.rendered

  vpc_security_group_ids = [
    aws_security_group.k3s-ingress.id
  ]
}

resource "aws_autoscaling_group" "k3s-agent" {
  name_prefix         = "k3s-agent"
  desired_capacity    = 3
  max_size            = 3
  min_size            = 3
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  target_group_arns = [
    aws_lb_target_group.agent-80.0.arn,
  ]

  launch_template {
    id = aws_launch_template.k3s-agent.id
  }
}

output "k3s-server" {
  description = "The server ip is"
  value       = aws_instance.k3s-server.public_ip
}

output "loadbalancer" {
  description = "The loadbalancer is"
  value       = aws_lb.lb.0.dns_name
}

resource "aws_lb" "lb" {
  count              = 1
  name               = "k3s-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnet_ids.default.ids
}

resource "aws_lb_listener" "port_80" {
  count             = 1
  load_balancer_arn = aws_lb.lb.0.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent-80.0.arn
  }
}

resource "aws_lb_target_group" "agent-80" {
  count    = 1
  port     = 80
  protocol = "TCP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_route53_zone" "primary" {
  name = "tom.works"
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "k3s.tom.works"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_lb.lb.0.dns_name]
}
