output "policy_assignment_id" {
  description = "Resource ID of the policy assignment."
  value       = azurerm_management_group_policy_assignment.aks_policy_addon.id
}

output "policy_assignment_principal_id" {
  description = "Principal (object) ID of the assignment's system-assigned managed identity."
  value       = azurerm_management_group_policy_assignment.aks_policy_addon.identity[0].principal_id
}

output "remediation_task_id" {
  description = "Resource ID of the remediation task, or null when not created."
  value       = try(azurerm_management_group_policy_remediation.aks_policy_addon[0].id, null)
}
