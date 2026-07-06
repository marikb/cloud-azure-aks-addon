#requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap an Azure Storage account for Terraform remote state. Run once.

.DESCRIPTION
    Creates (idempotently) the resource group, a globally-unique storage account
    (AAD-auth only, TLS 1.2, no public blob access, blob versioning + soft delete),
    and a container, then grants the signed-in user "Storage Blob Data Contributor"
    on the account (Owner/Contributor alone does NOT grant data-plane access).

    Afterwards, rename backend.tf.example to backend.tf in each module, fill in the
    values this script prints (use a DISTINCT key per module), and run terraform init.

.EXAMPLE
    ./scripts/Bootstrap-TfState.ps1 -StorageAccountName sttfstate12345 -Location westeurope

.NOTES
    Docs: https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage
#>

[CmdletBinding()]
param(
    [string]$ResourceGroupName = "rg-tfstate",

    # Storage account name: globally unique, 3-24 lowercase letters/numbers.
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string]$StorageAccountName,

    [string]$ContainerName = "tfstate",
    [string]$Location = "westeurope"
)

$ErrorActionPreference = 'Stop'
# az is a native command: don't let it throw; we check $LASTEXITCODE ourselves.
$PSNativeCommandUseErrorActionPreference = $false

Write-Host "Creating resource group '$ResourceGroupName'..."
az group create --name $ResourceGroupName --location $Location --output none
if ($LASTEXITCODE -ne 0) { throw "az group create failed. Are you signed in (az login)?" }

Write-Host "Creating storage account '$StorageAccountName' (AAD-auth only)..."
az storage account create `
    --name $StorageAccountName --resource-group $ResourceGroupName --location $Location `
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 `
    --allow-blob-public-access false --allow-shared-key-access false `
    --encryption-services blob --output none
if ($LASTEXITCODE -ne 0) { throw "az storage account create failed (name must be globally unique)." }

Write-Host "Enabling blob versioning and soft delete (state recovery)..."
az storage account blob-service-properties update `
    --account-name $StorageAccountName --resource-group $ResourceGroupName `
    --enable-versioning true --enable-delete-retention true --delete-retention-days 30 --output none
if ($LASTEXITCODE -ne 0) { throw "failed to set blob service properties." }

Write-Host "Granting you 'Storage Blob Data Contributor' on the account..."
$saId = az storage account show --name $StorageAccountName --resource-group $ResourceGroupName --query id -o tsv
$me = az ad signed-in-user show --query id -o tsv
az role assignment create --assignee $me --role "Storage Blob Data Contributor" --scope $saId --output none
if ($LASTEXITCODE -ne 0) { Write-Warning "  Role assignment failed; assign 'Storage Blob Data Contributor' manually before init." }

# Shared-key access is disabled, so the container is created with AAD auth. That
# needs the role above to have propagated, which can lag; retry a few times.
Write-Host "Creating container '$ContainerName'..."
$created = $false
for ($i = 1; $i -le 10; $i++) {
    az storage container create --name $ContainerName --account-name $StorageAccountName --auth-mode login --output none
    if ($LASTEXITCODE -eq 0) { $created = $true; break }
    Write-Host "  Waiting for RBAC propagation... ($i/10)"
    Start-Sleep -Seconds 15
}
if (-not $created) { throw "container create failed after retries - check the Storage Blob Data Contributor role assignment." }

Write-Host ""
Write-Host "Done. Put this in backend.tf in each module (rename backend.tf.example):"
Write-Host "  resource_group_name  = `"$ResourceGroupName`""
Write-Host "  storage_account_name = `"$StorageAccountName`""
Write-Host "  container_name       = `"$ContainerName`""
Write-Host "  use_azuread_auth     = true"
Write-Host "  key                  = `"aks-cluster.tfstate`"     # governance/: `"aks-governance.tfstate`""
