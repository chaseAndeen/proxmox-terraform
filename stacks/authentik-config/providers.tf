terraform {
  required_version = ">= 1.5.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = ">= 2024.8"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }

  backend "s3" {
    key = "authentik-config/terraform.tfstate"
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = data.aws_ssm_parameter.authentik_token.value
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}
