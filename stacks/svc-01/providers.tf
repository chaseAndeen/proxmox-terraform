terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.61.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    bucket         = "kernelstack-terraform-state"
    key            = "svc-01/terraform.tfstate"
    region         = "us-east-1"
    profile        = "InfraProvisioner"
    dynamodb_table = "kernelstack-terraform-locks"
    encrypt        = true
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = local.proxmox_api_token
  insecure  = var.proxmox_tls_insecure

  ssh {
    # Private key injected via PROXMOX_VE_SSH_PRIVATE_KEY env var by deploy.sh
    username = var.proxmox_ssh_user
    node {
      name    = var.proxmox_node
      address = var.proxmox_node_address
      port    = var.proxmox_ssh_port
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}
