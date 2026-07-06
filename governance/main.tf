locals {
  # Built-in policy: "Deploy Azure Policy Add-on to Azure Kubernetes Service clusters".
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/a8eff44f-8c92-45c3-a3fb-9880802d67a7"
}

# Resolve the management group's full resource ID from its name.
data "azurerm_management_group" "this" {
  name = var.management_group_name
}

# Assign the DeployIfNotExists policy at management-group scope. This installs the
# Azure Policy add-on on every current and future AKS cluster in the hierarchy.
resource "azurerm_management_group_policy_assignment" "aks_policy_addon" {
  name                 = var.assignment_name
  management_group_id  = data.azurerm_management_group.this.id
  policy_definition_id = local.policy_definition_id
  location             = var.identity_location
  description          = "Auto-install the Azure Policy add-on on all AKS clusters in this management group."

  identity {
    type = "SystemAssigned"
  }

  # parameters must be a JSON string; each parameter nests its value under "value".
  parameters = jsonencode({
    effect = {
      value = var.effect
    }
  })

  non_compliance_message {
    content = "AKS clusters must have the Azure Policy add-on enabled."
  }
}

# The DeployIfNotExists managed identity needs the policy's required roles at the
# assignment scope so its remediation deployments can enable the add-on.
resource "azurerm_role_assignment" "remediation" {
  for_each = toset(var.remediation_role_definition_ids)

  scope              = data.azurerm_management_group.this.id
  role_definition_id = "/providers/Microsoft.Authorization/roleDefinitions/${each.value}"
  principal_id       = azurerm_management_group_policy_assignment.aks_policy_addon.identity[0].principal_id

  # The assignment's managed identity is created in this same apply; skipping the
  # AAD existence pre-check avoids a PrincipalNotFound race from Entra ID
  # replication lag on first apply.
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# DeployIfNotExists only fires on create/update, so this remediation task backfills
# clusters that already exist. Skipped when the assignment is Disabled.
resource "azurerm_management_group_policy_remediation" "aks_policy_addon" {
  count = var.create_remediation_task && var.effect == "DeployIfNotExists" ? 1 : 0

  name                 = "remediate-${var.assignment_name}"
  management_group_id  = data.azurerm_management_group.this.id
  policy_assignment_id = azurerm_management_group_policy_assignment.aks_policy_addon.id
  # resource_discovery_mode is intentionally left at its default
  # (ExistingNonCompliant); "ReEvaluateCompliance" is only supported at
  # subscription scope and below, not at management-group scope.

  # RBAC must exist before remediation deploys. This resource is create-only, so a
  # plain `terraform apply` will NOT re-run it. Two first-run caveats: (1) a fresh
  # assignment has no compliance data yet, so the initial remediation may cover 0
  # clusters until the management-group compliance scan finishes (~30 min); (2) Entra
  # RBAC propagation can lag and cause AuthorizationFailed. In either case re-trigger:
  #   terraform apply -replace=azurerm_management_group_policy_remediation.aks_policy_addon[0]
  depends_on = [azurerm_role_assignment.remediation]
}
