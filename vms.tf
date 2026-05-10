resource "proxmox_virtual_environment_vm" "k8s_node" {
  for_each = local.k8s_nodes

  name        = each.key
  description = "Homelab / Kubernetes — managed by Terraform"
  tags        = ["homelab", "terraform", "k8s"]

  node_name = var.proxmox_node
  vm_id = each.value.vm_id

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  agent {
    enabled = true
  }

  stop_on_destroy = true

  clone {
    vm_id        = var.template_vm_id
    datastore_id = var.disk_datastore
    full         = true
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    datastore_id = var.disk_datastore

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 || each.value.dns_domain != null ? [1] : []
      content {
        domain  = each.value.dns_domain
        servers = var.dns_servers
      }
    }

    ip_config {
      ipv4 {
        address = each.value.ip_mode == "dhcp" ? "dhcp" : each.value.ipv4_cidr
        gateway = each.value.ip_mode == "dhcp" ? null : var.ipv4_gateway
      }
    }

    user_account {
      username = var.cloud_init_user
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  operating_system {
    type = "l26"
  }

  serial_device {}
}
