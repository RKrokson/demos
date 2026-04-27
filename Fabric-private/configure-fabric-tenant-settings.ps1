<#
.SYNOPSIS
    Configures Microsoft Fabric tenant-level admin settings required for the Fabric-byoVnet module.

.DESCRIPTION
    This script enables the tenant-level Fabric admin settings needed before deploying
    the Fabric-byoVnet Terraform module. It uses the Fabric Admin REST API to toggle
    each setting idempotently.

    PREREQUISITES:
    - Caller must have the "Fabric Administrator" role in the tenant
    - Azure CLI (az) must be installed and authenticated: az login
    - PowerShell 7+ (pwsh)

    SCOPE:
    - One-time per tenant (not per-deploy)
    - Safe to re-run — idempotent (checks current state before patching)

    SETTINGS CONFIGURED:
    1. Microsoft Fabric (EnableFabric) — enables Fabric for the tenant
    2. Workspace-level inbound network rules (WorkspaceLevelPrivateEndpointSettings)
    3. Users can create Fabric items (UsersCanCreateFabricItems)
    4. Service principals can call Fabric public APIs (ServicePrincipalsCanCallFabricPublicAPIs)

    After toggling setting #2, you MUST re-register the Microsoft.Fabric provider:
      az provider register --namespace Microsoft.Fabric

    DO NOT run this against a production tenant without understanding the impact.
    This is for lab/POC tenants only.

.NOTES
    Do not enable verbose PowerShell tracing (-Trace) when running this script — it will
    log the bearer token to the console.

.EXAMPLE
    ./configure-fabric-tenant-settings.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────
# Acquire token for Fabric Admin API
# ─────────────────────────────────────────────
Write-Host "Acquiring access token for Fabric Admin API..." -ForegroundColor Cyan
$tokenResponse = az account get-access-token --resource "https://api.fabric.microsoft.com" --query "{accessToken:accessToken}" -o json | ConvertFrom-Json
if (-not $tokenResponse.accessToken) {
    Write-Error "Failed to acquire access token. Ensure you are logged in with 'az login' and have Fabric Administrator role."
    exit 1
}
$headers = @{
    "Authorization" = "Bearer $($tokenResponse.accessToken)"
    "Content-Type"  = "application/json"
}
$baseUrl = "https://api.fabric.microsoft.com/v1"

# ─────────────────────────────────────────────
# Tenant settings to configure
# ─────────────────────────────────────────────
$settings = @(
    @{
        Name        = "EnableFabric"
        DisplayName = "Microsoft Fabric"
        Description = "Enables Microsoft Fabric for the tenant"
    },
    @{
        Name        = "WorkspaceLevelPrivateEndpointSettings"
        DisplayName = "Configure workspace-level inbound network rules"
        Description = "Allows workspace-level private endpoint configuration"
    },
    @{
        Name        = "UsersCanCreateFabricItems"
        DisplayName = "Users can create Fabric items"
        Description = "Allows users to create Fabric items in workspaces"
    },
    @{
        Name        = "ServicePrincipalsCanCallFabricPublicAPIs"
        DisplayName = "Service principals can call Fabric public APIs"
        Description = "Required when Terraform runs as a service principal"
    }
)

# ─────────────────────────────────────────────
# Check and enable each setting
# ─────────────────────────────────────────────
$reRegisterRequired = $false

foreach ($setting in $settings) {
    Write-Host "`nChecking: $($setting.DisplayName) ($($setting.Name))..." -ForegroundColor Yellow

    # Check current state
    try {
        $current = Invoke-RestMethod -Uri "$baseUrl/admin/tenantsettings/$($setting.Name)" `
            -Method Get -Headers $headers -ErrorAction Stop
        $currentState = $current.tenantSettingGroup.enabled
    }
    catch {
        Write-Host "  Could not read current state (may not exist yet). Will attempt to enable." -ForegroundColor DarkYellow
        $currentState = $false
    }

    if ($currentState -eq $true) {
        Write-Host "  Already enabled. Skipping." -ForegroundColor Green
        continue
    }

    # Enable the setting
    Write-Host "  Enabling..." -ForegroundColor Cyan
    $body = @{
        enabled = $true
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "$baseUrl/admin/tenantsettings/$($setting.Name)" `
            -Method Patch -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "  Enabled successfully." -ForegroundColor Green

        if ($setting.Name -eq "WorkspaceLevelPrivateEndpointSettings") {
            $reRegisterRequired = $true
        }
    }
    catch {
        Write-Warning "  Failed to enable $($setting.DisplayName): $_"
        Write-Warning "  You may need to configure this manually in the Fabric Admin Portal."
        Write-Warning "  Path: Admin portal -> Tenant settings -> $($setting.DisplayName)"
    }
}

# ─────────────────────────────────────────────
# Post-configuration: re-register Fabric provider if needed
# ─────────────────────────────────────────────
if ($reRegisterRequired) {
    Write-Host "`nWorkspace-level inbound network rules was just enabled." -ForegroundColor Yellow
    Write-Host "Re-registering Microsoft.Fabric resource provider (required after this toggle)..." -ForegroundColor Cyan
    az provider register --namespace Microsoft.Fabric
    Write-Host "Provider registration initiated. Check status with:" -ForegroundColor Green
    Write-Host "  az provider show -n Microsoft.Fabric --query registrationState -o tsv" -ForegroundColor White
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
Write-Host "`n─────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "Tenant configuration complete." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. If provider re-registration was triggered, wait for 'Registered' state"
Write-Host "  2. cd Fabric-byoVnet && terraform init && terraform plan"
Write-Host "─────────────────────────────────────────────" -ForegroundColor Cyan
