# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2026-07-06] - Key Vault CSI and host encryption

### Added
- Key Vault Secrets Provider (CSI driver) with secret rotation
  (`kv_secret_rotation_interval`) — pairs with the enabled Workload Identity. The
  Key Vault and `SecretProviderClass` are provisioned separately (app-level).
- Host encryption on the system node pool (`host_encryption_enabled`, default
  true). Requires the `Microsoft.Compute/EncryptionAtHost` subscription feature to
  be registered first; toggling it rotates the node pool in place.

## [2026-07-06] - Security hardening, policy enforcement & ops

### Added
- Cluster hardening (`terraform/aks-cluster.tf`): `local_account_disabled` (force
  all access through Entra), Workload Identity + OIDC issuer, Image Cleaner, Azure
  CNI Overlay with **Cilium** network policy (so NetworkPolicy is enforced), and an
  optional API-server authorized-IP allowlist (`api_server_authorized_ip_ranges`,
  empty = open so it can't lock you out). New variables/tfvars for each. Note the
  network profile is ForceNew — set at provisioning.
- Governance enforcement (`governance/`): assigns the built-in *"Kubernetes cluster
  pod security baseline standards for Linux-based workloads"* initiative
  (`a8640138-…`) in **Audit** mode by default, gated behind `assign_security_baseline`
  / `baseline_effect`. The module now enforces guardrails, not just installs the add-on.
- Optional remote state: `backend.tf.example` templates in both modules (azurerm
  backend with AAD auth, distinct state keys).
- Repo hygiene: root `.gitignore` and `.gitattributes` (LF normalization) to end the
  CRLF churn.
- Test coverage for the new hardening and the baseline initiative.

### Note
- A GitHub Actions CI workflow (fmt/validate/test on both modules) is prepared at
  `.github/workflows/terraform.yml` but is not committed in this change — pushing
  workflow files requires a token with `workflow` scope.

## [2026-07-06] - Upgrade to azurerm 4.x

### Changed
- Bumped the azurerm provider from `~> 3.117` to `~> 4.0` in both `terraform/` and
  `governance/`, and migrated the 4.0 breaking changes:
  - `automatic_channel_upgrade` → `automatic_upgrade_channel`.
  - `default_node_pool.enable_auto_scaling` → `auto_scaling_enabled`.
  - Removed `managed = true` from `azure_active_directory_role_based_access_control`
    (managed Entra integration is the only mode in 4.x).
  - Added the now-mandatory provider `subscription_id` (new `subscription_id`
    variable, or set the `ARM_SUBSCRIPTION_ID` environment variable).
- Regenerated the cross-platform provider lock files for azurerm 4.x.

## [2026-07-06] - Modernization & repository reorganization

### Changed
- Reorganized the repository into `terraform/` (infrastructure as code) and
  `scripts/` (Azure CLI automation), with a dedicated `terraform/tests/` suite.
- Upgraded the Terraform configuration from the end-of-life **azurerm 2.x** schema
  to **azurerm `~> 3.117`** and **azuread `~> 2.53`**:
  - `addon_profile { azure_policy { enabled = true } }` → top-level `azure_policy_enabled = true`.
  - `addon_profile { oms_agent { ... } }` → top-level `oms_agent { ... }`.
  - `role_based_access_control { azure_active_directory { ... } }` →
    `role_based_access_control_enabled` + `azure_active_directory_role_based_access_control`.
  - `default_node_pool` availability-zone argument `availability_zones` → `zones`.
  - Moved `upgrade_settings` inside `default_node_pool` (where it belongs).
- Extracted all inputs into `variables.tf` with validation, and added
  `outputs.tf`, `locals.tf`, and `terraform.tfvars.example` so the module is
  parameterized and reusable.
- Modernized the add-on script: the Azure Policy add-on for AKS is now Generally
  Available, so the obsolete `aks-preview` extension and
  `AKS-AzurePolicyAutoApprove` feature registration were removed. Renamed
  `install_aks.azcli` → `scripts/Enable-AksPolicyAddon.ps1` and repositioned it as
  an optional one-time backfill, with the `governance/` policy module as the
  recommended ongoing mechanism.

### Fixed
- **Script (`Enable-AksPolicyAddon.ps1`)**: corrected the inverted guard that
  caused the original script to *skip* subscriptions that had clusters and run on
  those that did not; replaced fragile index-based JSON parsing (`$i += 8`) with
  typed objects (`ConvertFrom-Json` + `foreach`); replaced the Bash `while [ ]`
  wait-loop with idiomatic PowerShell; added idempotency and per-cluster error
  handling.
- **`aks-cluster.tf`**: quoted the `automatic_channel_upgrade` value, corrected the
  misspelled `maintance_window` → `maintenance_window`, removed a stray closing
  brace and a duplicated `default_node_pool` block.
- **`locals.tf`** (extracted from the old `main.tf`): `local { }` → `locals { }`
  (the block name Terraform requires).
- **`aks-administrators-group.tf`**: deprecated `name` → `display_name` and added
  the now-required `security_enabled`.
- Pinned `kubernetes_version` to `major.minor` (derived from the versions data
  source) and set `ignore_changes` on both `kubernetes_version` and
  `default_node_pool[0].orchestrator_version` to stop the perpetual plan drift
  that occurs when the patch upgrade channel bumps the version out-of-band.
- Added `default_node_pool.temporary_name_for_rotation` so changing the node VM
  size, zones, or OS disk size rotates the node pool in place instead of
  destroying and recreating the entire cluster.
- Script error handling made deterministic across PowerShell 5.1 and 7.x: `az`
  exit codes are checked after every call, so a failed login, subscription
  switch, or per-cluster error no longer silently succeeds or aborts the run.

### Added
- New `governance/` Terraform root module: assigns the built-in
  *"Deploy Azure Policy Add-on to Azure Kubernetes Service clusters"*
  DeployIfNotExists policy (`a8eff44f-8c92-45c3-a3fb-9880802d67a7`) at
  management-group scope, grants the assignment's managed identity the two roles
  the policy requires, and creates a remediation task that backfills existing
  clusters once the initial compliance scan completes. This is the recommended
  at-scale mechanism (auto-covers new clusters, with compliance reporting) and
  resolves the script's long-standing "require the add-on on new clusters" TODO.
- Native `terraform test` suites (`terraform/tests/`, `governance/tests/`) using
  `mock_provider`, so tests run with **no Azure credentials**: plan-time assertions
  on configuration plus variable-validation failure tests.
- Configurable Log Analytics `sku` (`PerGB2018`) and retention, with managed-
  identity monitoring (`oms_agent.msi_auth_for_monitoring_enabled = true`).
- A `terraform/.gitignore` for state, local `.terraform/`, and `*.tfvars`.

## [2022-01-15] - Automatic AKS upgrading

- Define the automatic Kubernetes upgrade channel via `automatic_channel_upgrade`
  (`patch` / `rapid` / `node-image` / `stable`).
- Define the maintenance window for upgrades in `maintenance_window`.
- Set scalable node capacity to handle upgrades per Microsoft's recommendations in
  `upgrade_settings`.
- Microsoft also recommends deploying Kured for automatic reboots as needed:
  https://learn.microsoft.com/en-us/azure/aks/upgrade-node-image-kured

## [2020-11-17] - Managed Identity implementation

- Replaced Service Principal credentials with a managed identity (`SystemAssigned`)
  for a cleaner solution.
- Changed random name generation to Random Pet.
- Added an Azure AD group for cluster administrators.
- Added a data source that automatically resolves the latest available Kubernetes
  version.
- Added the OMS agent, wired to a Log Analytics workspace (30-day retention), for
  Azure Security Center monitoring.
- Enabled the Azure Policy add-on to deny potentially insecure configurations.
- Configured the node pool for high availability: spread across availability zones
  1-3 with autoscaling.
