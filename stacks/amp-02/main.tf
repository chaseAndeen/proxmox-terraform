module "vm" {
  source = "../../modules/proxmox-vm"

  # Identity
  vm_name        = "amp-02"
  vm_id          = 204
  vm_description = "AMP Target Node (game server worker) — managed by Terraform"
  vm_tags        = ["amp", "target", "terraform"]

  # Placement
  proxmox_node   = var.proxmox_node
  template_vm_id = 9001  # Debian Trixie — playbooks written and tested against Debian

  # Compute — sized for running multiple game server instances
  cpu_cores = 4
  memory    = 20480

  # Disk — game server files and saves need room to grow
  boot_disk_datastore = "vmdata"
  boot_disk_size      = 80

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
