#requires -Version 5.1
<#
.SYNOPSIS
    One-time backfill: enables the (GA) Azure Policy add-on on every existing AKS
    cluster across all subscriptions your account can access.

.DESCRIPTION
    Run in Azure Cloud Shell (PowerShell) or anywhere the Azure CLI is signed in
    (`az login`). For each enabled subscription that contains AKS clusters, the
    script registers the Microsoft.PolicyInsights provider and enables the
    azure-policy add-on on each cluster.

    The Azure Policy add-on for AKS is Generally Available, so the old preview
    steps (aks-preview extension, AKS-AzurePolicyAutoApprove feature) are no
    longer required and are intentionally omitted.

    This script is a point-in-time tool: it does NOT cover clusters created after
    it runs. For ongoing, at-scale governance use the governance/ Terraform module
    (a management-group DeployIfNotExists policy), which auto-installs the add-on
    on new clusters and reports compliance. Treat this script as an optional
    bootstrap for immediate enablement.

.NOTES
    Docs: https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes
#>

[CmdletBinding()]
param()

# Stop on PowerShell (cmdlet) errors...
$ErrorActionPreference = 'Stop'
# ...but do NOT let native `az` non-zero exits throw. This automatic variable only
# exists on PowerShell 7.3+ (harmless plain variable on 5.1). Forcing it $false
# makes az behavior identical across editions: az never throws, so we decide what
# to do by checking $LASTEXITCODE ourselves after each call.
$PSNativeCommandUseErrorActionPreference = $false

# Enumerate every enabled subscription the signed-in account can access.
$subscriptions = az account list --all --query "[?state=='Enabled']" -o json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw 'az account list failed. Are you signed in? Run "az login" first.'
}
if (-not $subscriptions) {
    Write-Warning 'No enabled subscriptions found.'
    return
}

foreach ($sub in $subscriptions) {
    Write-Host "=== Subscription: $($sub.name) [$($sub.id)] ==="

    # Scope subsequent az calls to this subscription.
    az account set --subscription $sub.id
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  Could not switch to subscription $($sub.name). Skipping."
        continue
    }

    # List AKS clusters in THIS subscription. An empty subscription returns [].
    $clusters = az aks list -o json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  az aks list failed for $($sub.name). Skipping."
        continue
    }
    # NOTE: the guard is deliberately NOT inverted. We skip only when there are
    # NO clusters (the original script wrongly skipped subscriptions that HAD
    # clusters). A single cluster deserializes to one object, many to an array;
    # foreach handles both, and -not correctly catches the empty ([] -> $null) case.
    if (-not $clusters) {
        Write-Host '  No AKS clusters found. Skipping.'
        continue
    }

    # Register the required resource provider once per subscription that has
    # clusters. --wait blocks until registration completes.
    Write-Host '  Registering Microsoft.PolicyInsights provider...'
    az provider register --namespace Microsoft.PolicyInsights --wait
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  Provider registration failed for $($sub.name). Skipping its clusters."
        continue
    }

    foreach ($cluster in $clusters) {
        $name = $cluster.name
        $rg = $cluster.resourceGroup

        # Idempotency: skip clusters that already have the add-on enabled.
        # az '-o tsv' renders the JSON boolean as lowercase 'true'/'false' (and a
        # missing add-on as 'None'); PowerShell -eq is case-insensitive.
        $enabled = az aks show --name $name --resource-group $rg `
            --query 'addonProfiles.azurepolicy.enabled' -o tsv
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  [$name] could not read add-on state; attempting to enable anyway."
        }
        elseif ($enabled -eq 'true') {
            Write-Host "  [$name] Azure Policy add-on already enabled. Skipping."
            continue
        }

        Write-Host "  [$name] Enabling azure-policy add-on (resource group: $rg)..."
        az aks enable-addons --addons azure-policy `
            --name $name --resource-group $rg --output none
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  [$name] enable-addons failed (exit code $LASTEXITCODE). Continuing."
            continue
        }
        Write-Host "  [$name] Enabled."
    }
}

Write-Host 'Done.'

# For ONGOING governance (new clusters auto-remediated + compliance reporting),
# assign the built-in DeployIfNotExists policy instead of re-running this script —
# see the governance/ Terraform module in this repo.
