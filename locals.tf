locals {
  # Expand this map as you add control-plane and worker nodes for Kubernetes.
  # Use unique vm_id values per guest (cluster-wide in Proxmox).
  k8s_nodes = {
    control-1 = {
      vm_id      = 201
      cores      = 2
      memory_mb  = 4096
      ip_mode    = "dhcp"
      ipv4_cidr  = null
      dns_domain = null
    }
    worker-1 = {
      vm_id      = 211
      cores      = 4
      memory_mb  = 8192
      ip_mode    = "dhcp"
      ipv4_cidr  = null
      dns_domain = null
    }
  }
}
