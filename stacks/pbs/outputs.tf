output "vm_id" {
  description = "Proxmox VM ID"
  value       = module.vm.vm_id
}

output "vm_name" {
  description = "VM hostname"
  value       = module.vm.vm_name
}

output "vm_ip" {
  description = "Static IPv4 address"
  value       = module.vm.vm_ip
}

output "pbs_ui" {
  description = "Proxmox Backup Server web UI URL"
  value       = "https://${module.vm.vm_ip}:8007"
}
