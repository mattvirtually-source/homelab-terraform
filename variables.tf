variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API URL, e.g. https://pve.lan:8006/"
}

variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS verification (typical for homelab self-signed certs)."
  default     = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name (Datacenter → Node) where VMs are created."
}

variable "template_vm_id" {
  type        = number
  description = "VM ID of a cloud-init template to full-clone (create a template in Proxmox first)."
}

variable "disk_datastore" {
  type        = string
  description = "Datastore ID for cloned disks (e.g. local-lvm, ceph-rbd)."
}

variable "network_bridge" {
  type        = string
  description = "Host bridge for guest NICs (e.g. vmbr0)."
  default     = "vmbr0"
}

variable "cloud_init_user" {
  type        = string
  description = "Linux user created by cloud-init on the template."
  default     = "ubuntu"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key for cloud-init user_account."
}

variable "ipv4_gateway" {
  type        = string
  description = "Default gateway for static IPv4 nodes (ignored when a node uses DHCP)."
  default     = null
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers written to cloud-init (empty = Proxmox/cloud default)."
  default     = []
}
