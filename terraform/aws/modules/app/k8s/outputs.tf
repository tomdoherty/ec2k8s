output "controller_ip" {
  description = "The controller ip is"
  value       = aws_instance.controller.public_ip
}

output "loadbalancer_ip" {
  description = "The loadbalancer ip is"
  value       = aws_elb.lb.dns_name
}
