variable "ingress_dns" {
  type = string
}


variable "name" {
  type = string
}


variable "tags" {
  type = map
}


variable "tcp_ingress_ports" {
  default = ["22", "80", "6443", "30171"]
  type    = set(string)
}


variable "worker_count" {
  type = number
}


variable "zone_id" {
  type = string
}
