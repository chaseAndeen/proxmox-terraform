module "vm" {
  source = "../../modules/proxmox-vm"

  # Identity
  vm_name        = "svc-01"
  vm_id          = var.vm_id
  vm_description = "Services VM (Traefik + Authentik) — managed by Terraform"
  vm_tags        = ["svc", "docker", "terraform"]

  # Placement
  proxmox_node   = var.proxmox_node
  template_vm_id = var.template_vm_id

  # Compute
  cpu_cores = 4
  memory    = 8192

  # Disk
  boot_disk_datastore = var.boot_disk_datastore
  boot_disk_size      = 40

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
