variable "region" {
  type    = string
  default = "us-west-2"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

source "amazon-ebs" "k8s" {
  ami_name      = "k8s-packer-${local.timestamp}"
  instance_type = "t2.micro"
  region        = var.region
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-xenial-16.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  tags = {
    app = "k8s"
  }
}

build {
  sources = ["source.amazon-ebs.k8s"]

  provisioner "ansible" {
    playbook_file = "../ansible/playbook.yml"
  }
}
