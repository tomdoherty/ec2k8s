resource "aws_route53_zone" "zone" {
  name = var.name
}

resource "null_resource" "update-domain" {
  provisioner "local-exec" {
    command = "aws route53domains update-domain-nameservers --region us-east-1 --domain-name ${var.name} --nameservers Name=${aws_route53_zone.zone.name_servers.0} Name=${aws_route53_zone.zone.name_servers.1} Name=${aws_route53_zone.zone.name_servers.2} Name=${aws_route53_zone.zone.name_servers.3}"
  }
}
