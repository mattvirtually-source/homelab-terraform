# homelab-terraform

Terraform for Proxmox VE (provider: [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)), focused on Kubernetes node VMs.

## Proxmox API user (one-time)

Terraform authenticates with an API token via `PROXMOX_VE_API_TOKEN` (see `providers.tf`). Create a dedicated user instead of using `root@pam`.

**Do not paste Proxmox passwords into chat or commit them to git.**

### Option A — from your Windows machine (API)

Set admin credentials in the environment, then run:

```powershell
$env:PROXMOX_ENDPOINT = "https://YOUR-PVE-HOST:8006/"
$env:PROXMOX_ADMIN_USER = "root@pam"
$env:PROXMOX_ADMIN_PASSWORD = "..."   # or use a secure prompt

.\scripts\setup-proxmox-terraform-user.ps1
```

Copy the printed token into your session:

```powershell
$env:PROXMOX_VE_API_TOKEN = "terraform@pve!terraform=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Option B — on a Proxmox node (SSH)

```bash
sudo bash scripts/setup-proxmox-terraform-user.sh
```

### After setup

1. Copy `terraform.tfvars.example` → `terraform.tfvars` and set `proxmox_endpoint`, `proxmox_node`, `template_vm_id`, etc.
2. Export `PROXMOX_VE_API_TOKEN` before `terraform plan` / `apply`.
3. Ensure a cloud-init template VM exists at `template_vm_id` on the target node.
