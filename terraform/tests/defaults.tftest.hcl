# Plan-time unit tests for the AKS configuration.
#
# Run from the terraform/ directory:
#   terraform init
#   terraform test
#
# mock_provider means NO Azure credentials or API calls are required.

mock_provider "azurerm" {
  # Pin the Kubernetes versions data source so local.kubernetes_version is
  # deterministic ("1.30.5" -> "1.30"). Data sources are read at plan time, so
  # these defaults are known during `command = plan`.
  mock_data "azurerm_kubernetes_service_versions" {
    defaults = {
      latest_version = "1.30.5"
      versions       = ["1.29.9", "1.30.5"]
    }
  }
}

mock_provider "azuread" {}
mock_provider "random" {}

run "defaults_produce_expected_cluster" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.aks.name == "aks-aks-app"
    error_message = "Cluster name should be aks-<resource_group_name>."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.kubernetes_version == "1.30"
    error_message = "kubernetes_version should be pinned to the major.minor derived from the versions data source."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.automatic_upgrade_channel == "patch"
    error_message = "Default automatic_upgrade_channel should be patch."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.azure_policy_enabled == true
    error_message = "The Azure Policy add-on must be enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.role_based_access_control_enabled == true
    error_message = "Role-based access control must be enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].auto_scaling_enabled == true
    error_message = "The system node pool should have autoscaling enabled."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].min_count == 1
    error_message = "Default system node pool min_count should be 1."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].max_count == 3
    error_message = "Default system node pool max_count should be 3."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.aks.default_node_pool[0].zones) == 3
    error_message = "The system node pool should span three availability zones."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.tags["Environment"] == "Staging"
    error_message = "The Environment tag should default to Staging."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.insights.retention_in_days == 30
    error_message = "Default Log Analytics retention should be 30 days."
  }
}

run "override_node_counts" {
  command = plan

  variables {
    system_node_min_count = 2
    system_node_max_count = 7
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].min_count == 2
    error_message = "min_count should reflect the overridden value."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].max_count == 7
    error_message = "max_count should reflect the overridden value."
  }
}

run "pinned_kubernetes_version_is_honored" {
  command = plan

  variables {
    kubernetes_version = "1.29"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.kubernetes_version == "1.29"
    error_message = "An explicitly pinned kubernetes_version should override the data-source default."
  }
}
