# Plan-time unit tests for the governance (policy assignment) module.
#
# Run from the governance/ directory:
#   terraform init
#   terraform test
#
# mock_provider means NO Azure credentials or API calls are required.

mock_provider "azurerm" {
  # Pin the management group data source so its id is known at plan time.
  mock_data "azurerm_management_group" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/test-mg"
    }
  }
}

variables {
  management_group_name = "test-mg"
}

run "assignment_configured_correctly" {
  command = plan

  assert {
    condition     = azurerm_management_group_policy_assignment.aks_policy_addon.policy_definition_id == "/providers/Microsoft.Authorization/policyDefinitions/a8eff44f-8c92-45c3-a3fb-9880802d67a7"
    error_message = "Assignment must reference the built-in AKS Policy add-on definition."
  }

  assert {
    condition     = azurerm_management_group_policy_assignment.aks_policy_addon.identity[0].type == "SystemAssigned"
    error_message = "Assignment must use a system-assigned managed identity."
  }

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.aks_policy_addon.parameters).effect.value == "DeployIfNotExists"
    error_message = "Default effect should be DeployIfNotExists."
  }

  assert {
    condition     = length(azurerm_role_assignment.remediation) == 2
    error_message = "Both roles the policy requires must be granted to the assignment identity."
  }

  assert {
    condition     = length(azurerm_management_group_policy_remediation.aks_policy_addon) == 1
    error_message = "A remediation task should be created by default (backfills existing clusters)."
  }
}

run "disabled_effect_skips_remediation" {
  command = plan

  variables {
    effect = "Disabled"
  }

  assert {
    condition     = length(azurerm_management_group_policy_remediation.aks_policy_addon) == 0
    error_message = "No remediation task should be created when the effect is Disabled."
  }
}

run "rejects_invalid_effect" {
  command = plan

  variables {
    effect = "Audit"
  }

  expect_failures = [
    var.effect,
  ]
}
