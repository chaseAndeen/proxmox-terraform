# ─── AWS ──────────────────────────────────────────────────────────────────────

variable "aws_profile" {
  description = "AWS CLI profile for SSM access"
  type        = string
  default     = "InfraProvisioner"
}

variable "aws_region" {
  description = "AWS region for SSM lookups"
  type        = string
  default     = "us-east-1"
}

# ─── Proxmox Connection ───────────────────────────────────────────────────────

variable "proxmox_api_url" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = false
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

variable "proxmox_node_address" {
  description = "Proxmox node IP or FQDN for provider SSH"
  type        = string
}

variable "proxmox_ssh_user" {
  description = "SSH user for Proxmox provider"
  type        = string
  default     = "ansible"
}

variable "proxmox_ssh_port" {
  description = "SSH port for Proxmox provider"
  type        = number
  default     = 2222
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vm_ip" {
  description = "Static IPv4 address for the VM"
  type        = string
}

variable "vm_cidr" {
  description = "Network prefix length"
  type        = number
  default     = 24
}

variable "vm_gateway" {
  description = "Default gateway"
  type        = string
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
}

variable "dns_search_domain" {
  description = "DNS search domain"
  type        = string
  default     = ""
}

# ─── VM Identity ──────────────────────────────────────────────────────────────

variable "vm_id" {
  description = "Proxmox VM ID — must be unique across the cluster"
  type        = number
}

variable "template_vm_id" {
  description = "Proxmox VM ID of the Packer-built template to clone"
  type        = number
}

# ─── Storage ──────────────────────────────────────────────────────────────────

variable "boot_disk_datastore" {
  description = "Proxmox storage pool for the VM boot disk (must be ZFS or LVM)"
  type        = string
  default     = "vmdata"
}
