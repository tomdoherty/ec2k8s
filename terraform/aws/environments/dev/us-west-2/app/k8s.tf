module "zone-dev-k8s" {
  source = "../../../../modules/app/route53_zone"
  name   = "tom.works"
}

module "k8s-dev" {
  source           = "../../../../modules/app/k8s"
  zone_id          = module.zone-dev-k8s.zone_id
  controller_count = 3
  worker_count     = 3
  ingress_dns      = "k8s.tom.works"
}
