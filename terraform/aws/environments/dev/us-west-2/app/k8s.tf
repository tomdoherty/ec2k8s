module "zone-dev-k8s" {
  source = "../../../../modules/app/route53_zone"
  domain = "tom.works"
}

module "k8s-dev" {
  source = "../../../../modules/app/k8s"
  name   = "k8s"

  controller_ami  = "ami-08d70e59c07c61a3a"
  controller_size = "t2.micro"

  ingress_dns = "k8s.tom.works"

  ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9FNpoDiJLd+if9noTjimmiCfTi0BUa3uQFnUOf5PVLx+gT0+61j7+EOvvqdVN8pUI/+eNMJPqDvrPsKqe63QJkDboltJaY9m39KAPAVw/L8myLDsxcXprmLOtK8MlHc1FvGwsUeiZAZaEdt/KfOd/zkU/qd5xpQVk9ERO/H+o3T5ReuEV63vlSnF8mXvh5gFzJVLiTgMgGhYizg24Z894nalGx+rvPz1XWVhEqlZsQsdyXQsnUdoboSyVw1tcN3y87Tws8k72ZRMd5Yc9zs+5XN3Yj4DOtJzac0wvcFAVIetHMz2BWUbT5Ei9BDAjGerI+nr47p5CDetyqy82Ctwz tom@Thomass-MacBook-Pro.local"

  worker_ami   = "ami-08d70e59c07c61a3a"
  worker_count = 3
  worker_size  = "t2.micro"

  zone_id = module.zone-dev-k8s.zone_id

  vpc_cidr                = "10.0.0.0/16"
  vpc_subnet_public_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  vpc_availability_zones  = ["us-west-2a", "us-west-2b", "us-west-2c"]

  tags = {
    app = "k8s"
  }
}
