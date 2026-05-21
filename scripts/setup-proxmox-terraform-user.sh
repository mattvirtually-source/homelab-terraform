#!/usr/bin/env bash
# Run on a Proxmox node as root (or any host with pveum and cluster admin).
set -euo pipefail

TERRAFORM_USER="${PROXMOX_TERRAFORM_USER:-terraform@pve}"
TOKEN_ID="${PROXMOX_TERRAFORM_TOKEN:-terraform}"
ROLE_NAME="${PROXMOX_TERRAFORM_ROLE:-TerraformHomelab}"

PRIVS="Datastore.Allocate,Datastore.AllocateSpace,VM.Allocate,VM.Audit,VM.Clone,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.GuestAgent.Audit,VM.PowerMgmt"

if ! id "$TERRAFORM_USER" &>/dev/null; then
  pveum user add "$TERRAFORM_USER" --comment "Terraform homelab (homelab-terraform repo)"
fi

if pveum role list | awk '{print $1}' | grep -qx "$ROLE_NAME"; then
  pveum role modify "$ROLE_NAME" -privs "$PRIVS"
else
  pveum role add "$ROLE_NAME" -privs "$PRIVS"
fi

pveum aclmod / -user "$TERRAFORM_USER" -role "$ROLE_NAME"

pveum user token remove "$TERRAFORM_USER" "$TOKEN_ID" 2>/dev/null || true
TOKEN_OUT="$(pveum user token add "$TERRAFORM_USER" "$TOKEN_ID" --privsep=0 --comment homelab-terraform)"

echo ""
echo "=== Proxmox Terraform API token (save now; shown once) ==="
# pveum prints key=value; build full token id for PROXMOX_VE_API_TOKEN
SECRET="$(echo "$TOKEN_OUT" | awk '/value/ {print $NF}')"
echo "${TERRAFORM_USER}!${TOKEN_ID}=${SECRET}"
echo ""
echo "export PROXMOX_VE_API_TOKEN='${TERRAFORM_USER}!${TOKEN_ID}=${SECRET}'"
