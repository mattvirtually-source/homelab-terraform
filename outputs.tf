output "k8s_node_vm_ids" {
  description = "Proxmox VM IDs for each Kubernetes node."
  value       = { for k, v in proxmox_virtual_environment_vm.k8s_node : k => v.vm_id }
}

output "k8s_node_names" {
  description = "Guest names as seen in Proxmox."
  value       = { for k, v in proxmox_virtual_environment_vm.k8s_node : k => v.name }
}
