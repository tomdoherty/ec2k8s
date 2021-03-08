variable "name" {
  type = string
}


variable "vpc_cidr" {
  type = string
}


variable "vpc_availability_zones" {
  type = list
}


variable "vpc_subnet_public_cidrs" {
  type = list
}


variable "tags" {
  type = map
}
