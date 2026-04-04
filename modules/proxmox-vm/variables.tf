# ─── VM Identity ──────────────────────────────────────────────────────────────

variable "vm_name" {
  description = "VM hostname"
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID"
  type        = number
}

variable "vm_description" {
  description = "VM description shown in Proxmox UI"
  type        = string
}

variable "vm_tags" {
  description = "List of tags to apply to the VM"
  type        = list(string)
  default     = ["terraform"]
}

# ─── Proxmox Placement ────────────────────────────────────────────────────────

variable "proxmox_node" {
  description = "Proxmox node to deploy the VM on"
  type        = string
}

variable "template_vm_id" {
  description = "VM ID of the template to clone"
  type        = number
}

# ─── Compute ──────────────────────────────────────────────────────────────────

variable "cpu_cores" {
  description = "Number of vCPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM in MB"
  type        = number
  default     = 4096
}

# ─── Disk ─────────────────────────────────────────────────────────────────────

variable "boot_disk_datastore" {
  description = "Proxmox datastore for the boot disk"
  type        = string
  default     = "vmdata"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag for the network interface (null for untagged)"
  type        = number
  default     = null
  nullable    = true
}

variable "vm_ip" {
  description = "Static IPv4 address (without prefix length)"
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

# ─── Cloud-Init ───────────────────────────────────────────────────────────────

variable "ansible_public_key" {
  description = "SSH public key to inject for the ansible service account"
  type        = string
  sensitive   = true
}
