#Requires -Version 5.1
<#
.SYNOPSIS
  Creates a dedicated Proxmox API user, role, ACL, and token for this Terraform repo.

.DESCRIPTION
  Uses admin credentials from the environment (do not pass passwords on the command line).
  Prints the API token once; store it as PROXMOX_VE_API_TOKEN.

  Uses curl.exe for HTTPS (Windows PowerShell 5.1 often cannot speak TLS to Proxmox).

  Required environment variables:
    PROXMOX_ENDPOINT          e.g. https://pve.lan:8006/
    PROXMOX_ADMIN_USER        e.g. root@pam
    PROXMOX_ADMIN_PASSWORD    (or omit to be prompted interactively)

  Optional:
    PROXMOX_TERRAFORM_USER    default: terraform@pve
    PROXMOX_TERRAFORM_TOKEN   default: terraform
    PROXMOX_TERRAFORM_ROLE    default: TerraformHomelab
#>
[CmdletBinding()]
param(
  [string] $Endpoint = $env:PROXMOX_ENDPOINT,
  [string] $AdminUser = $env:PROXMOX_ADMIN_USER,
  [string] $AdminPassword = $env:PROXMOX_ADMIN_PASSWORD,
  [string] $TerraformUser = $(if ($env:PROXMOX_TERRAFORM_USER) { $env:PROXMOX_TERRAFORM_USER } else { "terraform@pve" }),
  [string] $TokenId = $(if ($env:PROXMOX_TERRAFORM_TOKEN) { $env:PROXMOX_TERRAFORM_TOKEN } else { "terraform" }),
  [string] $RoleName = $(if ($env:PROXMOX_TERRAFORM_ROLE) { $env:PROXMOX_TERRAFORM_ROLE } else { "TerraformHomelab" })
)

$ErrorActionPreference = "Stop"

if (-not $Endpoint -or -not $AdminUser) {
  throw "Set PROXMOX_ENDPOINT and PROXMOX_ADMIN_USER before running this script."
}

if (-not $AdminPassword) {
  $secure = Read-Host "Proxmox password for $AdminUser" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $AdminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
  throw "curl.exe not found. Install curl or use the shell script on a Proxmox node."
}

$Endpoint = $Endpoint.TrimEnd("/")

# Privileges needed for proxmox_virtual_environment_vm in this repo (clone, cloud-init, power).
$Privileges = @(
  "Datastore.Allocate",
  "Datastore.AllocateSpace",
  "VM.Allocate",
  "VM.Audit",
  "VM.Clone",
  "VM.Config.Cloudinit",
  "VM.Config.CPU",
  "VM.Config.Disk",
  "VM.Config.HWType",
  "VM.Config.Memory",
  "VM.Config.Network",
  "VM.Config.Options",
  "VM.GuestAgent.Audit",
  "VM.PowerMgmt"
) -join ","

function Format-ProxmoxForm {
  param([hashtable] $Form)
  if ($Form.Count -eq 0) { return $null }
  ($Form.GetEnumerator() | ForEach-Object {
    "{0}={1}" -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value)
  }) -join "&"
}

function Invoke-ProxmoxApi {
  param(
    [ValidateSet("GET", "POST", "PUT", "DELETE")]
    [string] $Method,
    [string] $Path,
    [hashtable] $Form = @{},
    [string] $Ticket,
    [string] $Csrf,
    [switch] $AllowFailure
  )

  $uri = "$Endpoint/api2/json$Path"
  $curlArgs = @("-sk", "-X", $Method)

  if ($Ticket) {
    $curlArgs += @("-b", "PVEAuthCookie=$Ticket")
    if ($Method -ne "GET" -and $Csrf) {
      $curlArgs += @("-H", "CSRFPreventionToken: $Csrf")
    }
  }

  $body = Format-ProxmoxForm -Form $Form
  if ($body) {
    $curlArgs += @("--data-raw", $body)
  }

  $curlArgs += $uri
  $raw = & curl.exe @curlArgs 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "curl failed ($LASTEXITCODE): $raw"
  }

  $json = $raw | ConvertFrom-Json
  if ($null -ne $json.message -and $json.message -match '\S' -and -not $AllowFailure) {
    throw $json.message.Trim()
  }

  if ($null -eq $json.data) {
    return $json
  }
  return $json.data
}

Write-Host "Authenticating to $Endpoint as $AdminUser ..."
$auth = Invoke-ProxmoxApi -Method POST -Path "/access/ticket" -Form @{
  username = $AdminUser
  password = $AdminPassword
}
$ticket = $auth.ticket
$csrf = $auth.CSRFPreventionToken

Write-Host "Ensuring user $TerraformUser exists ..."
$userPath = "/access/users/$([uri]::EscapeDataString($TerraformUser))"
$userExists = $false
try {
  Invoke-ProxmoxApi -Method GET -Path $userPath -Ticket $ticket -Csrf $csrf | Out-Null
  $userExists = $true
  Write-Host "  User already exists."
} catch {
  if ($_.Exception.Message -notmatch 'does not exist|no such user') {
    throw
  }
}

if (-not $userExists) {
  Invoke-ProxmoxApi -Method POST -Path "/access/users" -Ticket $ticket -Csrf $csrf -Form @{
    userid  = $TerraformUser
    comment = "Terraform homelab (homelab-terraform repo)"
  } | Out-Null
  Write-Host "  User created."
}

Write-Host "Ensuring role $RoleName exists ..."
$roleExists = $false
try {
  $existing = Invoke-ProxmoxApi -Method GET -Path "/access/roles/$RoleName" -Ticket $ticket -Csrf $csrf
  $roleExists = $true
  if ($existing.privs -ne $Privileges) {
    Invoke-ProxmoxApi -Method PUT -Path "/access/roles/$RoleName" -Ticket $ticket -Csrf $csrf -Form @{
      privs = $Privileges
    } | Out-Null
    Write-Host "  Role updated with required privileges."
  } else {
    Write-Host "  Role already exists with correct privileges."
  }
} catch {
  if ($_.Exception.Message -notmatch 'does not exist|no such role') {
    throw
  }
}

if (-not $roleExists) {
  Invoke-ProxmoxApi -Method POST -Path "/access/roles" -Ticket $ticket -Csrf $csrf -Form @{
    roleid = $RoleName
    privs  = $Privileges
  } | Out-Null
  Write-Host "  Role created."
}

Write-Host "Applying ACL: $RoleName on / for $TerraformUser ..."
Invoke-ProxmoxApi -Method PUT -Path "/access/acl" -Ticket $ticket -Csrf $csrf -Form @{
  path      = "/"
  users     = $TerraformUser
  roles     = $RoleName
  propagate = "1"
} | Out-Null

$tokenPath = "/access/users/$([uri]::EscapeDataString($TerraformUser))/token/$([uri]::EscapeDataString($TokenId))"
Write-Host "Creating API token $TerraformUser!$TokenId (privilege separation disabled for token ACL inheritance) ..."

Invoke-ProxmoxApi -Method DELETE -Path $tokenPath -Ticket $ticket -Csrf $csrf -AllowFailure | Out-Null

$token = Invoke-ProxmoxApi -Method POST -Path $tokenPath -Ticket $ticket -Csrf $csrf -Form @{
  privsep = "0"
  comment = "homelab-terraform"
}

$apiToken = "$($token.'full-tokenid')=$($token.value)"
Write-Host ""
Write-Host "=== Proxmox Terraform API token (save now; shown once) ===" -ForegroundColor Green
Write-Host $apiToken
Write-Host ""
Write-Host "PowerShell (current session):" -ForegroundColor Yellow
Write-Host ('$env:PROXMOX_VE_API_TOKEN = "{0}"' -f $apiToken)
Write-Host ""
Write-Host "Add to terraform.tfvars: proxmox_endpoint = `"$Endpoint/`"" -ForegroundColor Yellow
