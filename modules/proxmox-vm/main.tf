terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.61.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.vm_name
  description = var.vm_description
  tags        = var.vm_tags

  node_name = var.proxmox_node
  vm_id     = var.vm_id

  clone {
    vm_id   = var.template_vm_id
    full    = true
    retries = 3
  }

  agent {
    enabled = true
  }

  cpu {
    cores   = var.cpu_cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.boot_disk_datastore
    interface    = "scsi0"
    size         = var.boot_disk_size
    discard      = "on"
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge   = var.network_bridge
    model    = "virtio"
    vlan_id  = var.vlan_id
    firewall = false
  }

  initialization {
    datastore_id = var.boot_disk_datastore

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${var.vm_cidr}"
        gateway = var.vm_gateway
      }
    }

    dns {
      servers = var.dns_servers
      domain  = var.dns_search_domain
    }

    # ansible service account injected at VM creation so proxmox-playbook
    # can connect immediately without a bootstrap run.
    # All other user accounts and config are handled by proxmox-playbook.
    user_account {
      username = "ansible"
      keys     = [trimspace(var.ansible_public_key)]
    }
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    ignore_changes = [disk]
  }
}
