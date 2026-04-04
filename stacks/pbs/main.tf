module "vm" {
  source = "../../modules/proxmox-vm"

  # Identity
  vm_name        = "pbs-01"
  vm_id          = 200
  vm_description = "Proxmox Backup Server — managed by Terraform"
  vm_tags        = ["pbs", "terraform"]

  # Placement
  proxmox_node   = var.proxmox_node
  template_vm_id = 9001

  # Compute
  cpu_cores = 4
  memory    = 8192

  # Disk
  boot_disk_datastore = "vmdata"
  boot_disk_size      = 32

  # Networking
  network_bridge    = var.network_bridge
  vm_ip             = var.vm_ip
  vm_cidr           = var.vm_cidr
  vm_gateway        = var.vm_gateway
  dns_servers       = var.dns_servers
  dns_search_domain = var.dns_search_domain

  # Cloud-init
  ansible_public_key = data.aws_ssm_parameter.ansible_public_key.value
}
