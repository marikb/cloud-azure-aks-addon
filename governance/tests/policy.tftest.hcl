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

  assert {
    condition     = length(azurerm_management_group_policy_assignment.security_baseline) == 1
    error_message = "The pod-security baseline initiative should be assigned by default."
  }

  assert {
    condition     = endswith(azurerm_management_group_policy_assignment.security_baseline[0].policy_definition_id, "a8640138-9b0a-4a28-b8cb-1666c838647d")
    error_message = "The baseline assignment must reference the built-in pod-security baseline initiative."
  }

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.security_baseline[0].parameters).effect.value == "Audit"
    error_message = "The baseline initiative should default to Audit effect."
  }

  assert {
    condition     = contains(jsondecode(azurerm_management_group_policy_assignment.security_baseline[0].parameters).excludedNamespaces.value, "kube-system")
    error_message = "System namespaces should be excluded from the baseline initiative."
  }
}

run "baseline_deny_mode" {
  command = plan

  variables {
    baseline_effect = "Deny"
  }

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.security_baseline[0].parameters).effect.value == "Deny"
    error_message = "Setting baseline_effect to Deny should propagate to the initiative."
  }
}

run "baseline_can_be_disabled" {
  command = plan

  variables {
    assign_security_baseline = false
  }

  assert {
    condition     = length(azurerm_management_group_policy_assignment.security_baseline) == 0
    error_message = "No baseline assignment should be created when assign_security_baseline is false."
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
