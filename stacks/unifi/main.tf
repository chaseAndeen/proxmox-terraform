module "vm" {
  source = "../../modules/proxmox-vm"

  # Identity
  vm_name        = "unifi-01"
  vm_id          = 202
  vm_description = "UniFi OS Server — managed by Terraform"
  vm_tags        = ["unifi", "terraform"]

  # Placement
  proxmox_node   = var.proxmox_node
  template_vm_id = 9001 # Debian Trixie

  # Compute — UniFi OS Server minimum: 4 cores, 4 GB RAM
  cpu_cores = 4
  memory    = 4096

  # Disk — UniFi OS Server minimum: 20 GB
  boot_disk_datastore = "vmdata"
  boot_disk_size      = 32

  # Networking — untagged on the main LAN (192.168.10.x)
  network_bridge    = var.network_bridge
  vm_ip             = var.vm_ip
  vm_cidr           = var.vm_cidr
  vm_gateway        = var.vm_gateway
  dns_servers       = var.dns_servers
  dns_search_domain = var.dns_search_domain

  # Cloud-init
  ansible_public_key = data.aws_ssm_parameter.ansible_public_key.value
}
