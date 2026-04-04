data "aws_ssm_parameter" "proxmox_api_token" {
  name            = "/infra/proxmox/terraform_token"
  with_decryption = true
}

data "aws_ssm_parameter" "ansible_public_key" {
  name            = "/infra/common/ansible_public_key"
  with_decryption = true
}

locals {
  proxmox_api_token = "terraform-prov@pve!terraform-token=${data.aws_ssm_parameter.proxmox_api_token.value}"
}
