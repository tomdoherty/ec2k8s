output "vpc_id" {
  value = aws_vpc.vpc.id
}


output "sn_public_ids" {
  value = aws_subnet.subnet_public[*].id
}
