output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_name" {
  description = "VM hostname"
  value       = proxmox_virtual_environment_vm.this.name
}

output "vm_ip" {
  description = "Static IPv4 address"
  value       = var.vm_ip
}
