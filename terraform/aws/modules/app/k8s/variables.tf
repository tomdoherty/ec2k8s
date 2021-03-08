variable "vpc_cidr" {
  type = string
}

variable "vpc_availability_zones" {
  type = list
}

variable "vpc_subnet_public_cidrs" {
  type = list
}


variable "controller_ami" {
  type = string
}


variable "controller_size" {
  type = string
}


variable "ingress_dns" {
  type = string
}


variable "name" {
  type = string
}


variable "ssh_public_key" {
  type = string
}


variable "tags" {
  type = map
}


variable "target_port" {
  type    = number
  default = 30171
}


variable "tcp_ingress_ports" {
  default = ["22", "80", "6443", "30171"]
  type    = set(string)
}


variable "worker_ami" {
  type = string
}


variable "worker_count" {
  type = number
}


variable "worker_size" {
  type = string
}


variable "zone_id" {
  type = string
}
