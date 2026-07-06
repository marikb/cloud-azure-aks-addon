resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_name
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  dns_prefix          = local.cluster_name

  kubernetes_version        = local.kubernetes_version
  automatic_upgrade_channel = var.automatic_channel_upgrade

  # Hardening: force all cluster access through managed Entra (no local admin),
  # and enable Workload Identity (federated pod identities) with its OIDC issuer.
  local_account_disabled    = var.local_account_disabled
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Garbage-collect stale/vulnerable images off the nodes.
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = var.image_cleaner_interval_hours

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name    = "system"
    vm_size = var.system_node_vm_size
    zones   = var.availability_zones
    # BYO subnet only for a private cluster; null uses the AKS-managed VNet.
    vnet_subnet_id       = var.private_cluster_enabled ? azurerm_subnet.aks[0].id : null
    auto_scaling_enabled = true
    min_count            = var.system_node_min_count
    max_count            = var.system_node_max_count
    os_disk_size_gb      = var.system_node_os_disk_size_gb
    # Encrypt the VM host (temp disk + OS/data disk caches) at rest. ForceNew, but
    # rotates in place via temporary_name_for_rotation below. Requires the
    # Microsoft.Compute/EncryptionAtHost subscription feature to be registered.
    host_encryption_enabled = var.host_encryption_enabled
    # orchestrator_version is intentionally left unset: AKS manages it via the
    # automatic upgrade channel, and pinning it here conflicts with auto-upgrade.

    # Rotate the node pool in place when a ForceNew attribute (vm_size, zones,
    # os_disk_size_gb) changes, instead of destroying and recreating the whole
    # cluster. Must be a valid node pool name (<= 12 chars for a system pool).
    temporary_name_for_rotation = "systemtmp"

    upgrade_settings {
      max_surge = var.node_max_surge
    }
  }

  # Azure CNI Overlay + Cilium data plane and network policy, so NetworkPolicy
  # objects are actually enforced (the default kubenet silently ignores them).
  # NOTE: the whole network_profile block is ForceNew — set it at provisioning
  # time; changing it later recreates the cluster.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  # Restrict the public API server to an allowlist. Rendered only when ranges are
  # provided — an empty list leaves the API server open rather than locking
  # everyone out. Populate with your client egress (e.g. Cloud Shell) to enable.
  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  # Private cluster (opt-in). private_cluster_enabled is ForceNew — enabling it on
  # an existing cluster recreates it. The DNS-zone and public-FQDN settings only
  # apply when private.
  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_enabled ? var.private_cluster_public_fqdn_enabled : false
  private_dns_zone_id                 = var.private_cluster_enabled ? var.private_dns_zone_id : null

  # Azure Policy add-on (top-level boolean).
  azure_policy_enabled = true

  # Secrets Store CSI driver — lets pods mount Key Vault secrets/certs. Pairs with
  # the Workload Identity enabled above. The Key Vault and SecretProviderClass are
  # provisioned separately (app-level); this only installs the driver.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = var.kv_secret_rotation_interval
  }

  # Container Insights / Log Analytics monitoring. msi_auth uses the cluster's
  # managed identity to publish metrics instead of the workspace shared key.
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.insights.id
    msi_auth_for_monitoring_enabled = true
  }

  # Managed Azure AD integration with a dedicated cluster-admin group.
  role_based_access_control_enabled = true

  # managed Entra integration is the only mode in azurerm 4.x (no `managed` arg).
  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [azuread_group.aks_administrators.object_id]
    azure_rbac_enabled     = var.azure_rbac_enabled
  }

  maintenance_window {
    allowed {
      day   = var.maintenance_day
      hours = var.maintenance_hours
    }
  }

  tags = local.common_tags

  lifecycle {
    # The patch upgrade channel bumps the version out-of-band on both the control
    # plane and the node pool; ignore that drift so Terraform does not try to
    # revert AKS's auto-applied patch on the next plan.
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].orchestrator_version,
    ]
  }
}
