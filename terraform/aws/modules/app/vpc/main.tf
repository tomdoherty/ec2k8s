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
  for_each                = toset(var.vpc_subnet_public_cidrs)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = element(var.vpc_availability_zones, index(var.vpc_subnet_public_cidrs, each.key))
  cidr_block              = element(var.vpc_subnet_public_cidrs, index(var.vpc_subnet_public_cidrs, each.key))
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
  for_each       = toset(var.vpc_subnet_public_cidrs)
  subnet_id      = aws_subnet.subnet_public[each.key].id
  route_table_id = aws_route_table.rtb_public.id
}
