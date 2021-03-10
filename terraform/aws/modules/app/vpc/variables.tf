variable "name" {
  type = string
}


variable "vpc_cidr" {
  type = string
}


variable "vpc_availability_zones" {
  type = list(any)
}


variable "vpc_subnet_public_cidrs" {
  type = list(any)
}


variable "tags" {
  type = map(any)
}
