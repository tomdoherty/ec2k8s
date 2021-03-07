module "zone-dev-k8s" {
  source = "../../../../modules/app/route53_zone"
  domain = "tom.works"
}

module "k8s-dev" {
  source       = "../../../../modules/app/k8s"
  name         = "k8s"
  zone_id      = module.zone-dev-k8s.zone_id
  worker_count = 3
  ingress_dns  = "k8s.tom.works"

  tags = {
    app = "k8s"
  }
}
