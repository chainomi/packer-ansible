packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

locals {
  ami_prefix = "debian-ami"
  ami_suffix = formatdate("YYYY.MM.DD.HH.MM", timestamp())
  ami_name   = "${local.ami_prefix}-${local.ami_suffix}"
  base_instance = {
    # profile  = "PackerBuildTempInstEC2Profile"
    type     = "t4g.medium"
    ssh_user = "admin"
  }
  encrypted = true
}

data "amazon-ami" "debian-source-ami" {
  filters = {
    virtualization-type = "hvm"
    name                = "*debian-12-arm64-*"
    root-device-type    = "ebs"
  }
  owners      = ["amazon"]
  most_recent = true
  region      = var.region
}

source "amazon-ebs" "debian-ami" {
  ami_name      = local.ami_name
  instance_type = local.base_instance.type
  region        = var.region
  source_ami    = data.amazon-ami.debian-source-ami.id
  ssh_username  = local.base_instance.ssh_user
  # iam_instance_profile = local.base_instance.profile
  encrypt_boot = local.encrypted

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }


  tags = {
    "Name"          = "debian-ami"
    "Created_By"    = "Packer"
    "Base_OS"       = data.amazon-ami.debian-source-ami.name
    "Creation_Date" = local.ami_suffix
    "Purpose"       = "Base image for Debian instance"
  }
}

build {
  sources = ["source.amazon-ebs.debian-ami"]

  provisioner "ansible" {
    playbook_file = "./debian-playbook.yml"
    user          = local.base_instance.ssh_user
  }

}
