module "vm" {
  source = "../../modules/proxmox-vm"

  # Identity
  vm_name        = "amp-01"
  vm_id          = 203
  vm_description = "AMP Management Node (ADS controller) — managed by Terraform"
  vm_tags        = ["amp", "ads", "terraform"]

  # Placement
  proxmox_node   = var.proxmox_node
  template_vm_id = 9001  # Debian Trixie — playbooks written and tested against Debian

  # Compute — ADS is lightweight; game servers run on amp-02
  cpu_cores = 2
  memory    = 4096

  # Disk
  boot_disk_datastore = "vmdata"
  boot_disk_size      = 30

  # Networking
  network_bridge    = var.network_bridge
  vlan_id           = var.vlan_id
  vm_ip             = var.vm_ip
  vm_cidr           = var.vm_cidr
  vm_gateway        = var.vm_gateway
  dns_servers       = var.dns_servers
  dns_search_domain = var.dns_search_domain

  # Cloud-init
  ansible_public_key = data.aws_ssm_parameter.ansible_public_key.value
}
