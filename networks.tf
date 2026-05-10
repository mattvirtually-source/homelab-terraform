# Physical Linux bridges (vmbr0, VLAN-aware bridges, etc.) and most SDN design
# are usually configured on the Proxmox hosts or outside this repo. Terraform
# here attaches VMs to an existing bridge via `var.network_bridge` in vms.tf.
#
# When you introduce VLANs or overlay networks for Kubernetes (e.g. Cilium,
# Calico), you typically keep the node NIC on a trunk/access bridge and let the
# CNI handle cluster networking — no extra Proxmox "network" resource required.
#
# If you later manage Proxmox SDN in code, add resources from the bpg/proxmox
# provider (e.g. SDN zones/vnets) in this file.
