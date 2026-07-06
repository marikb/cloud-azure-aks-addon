variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for the azurerm provider (required by azurerm 4.x). Leave null to fall back to the ARM_SUBSCRIPTION_ID environment variable."
  default     = null
}

variable "management_group_name" {
  type        = string
  description = <<-EOT
    Name (not the full resource ID) of the management group to assign the policy
    at. Every AKS cluster in this management group hierarchy is governed. For the
    tenant root management group, the name is the tenant ID.
  EOT
}

variable "identity_location" {
  type        = string
  description = "Azure region for the policy assignment's system-assigned managed identity."
  default     = "westeurope"
}

variable "assignment_name" {
  type        = string
  description = "Name of the policy assignment (3-24 characters)."
  default     = "aks-policy-addon"

  validation {
    condition     = length(var.assignment_name) >= 3 && length(var.assignment_name) <= 24
    error_message = "assignment_name must be between 3 and 24 characters."
  }
}

variable "effect" {
  type        = string
  description = "Policy effect. 'DeployIfNotExists' installs/remediates the add-on; 'Disabled' turns the assignment off."
  default     = "DeployIfNotExists"

  validation {
    condition     = contains(["DeployIfNotExists", "Disabled"], var.effect)
    error_message = "effect must be either DeployIfNotExists or Disabled (the only values this built-in policy allows)."
  }
}

variable "create_remediation_task" {
  type        = bool
  description = <<-EOT
    Create a remediation task to backfill EXISTING clusters (DeployIfNotExists only
    auto-acts on create/update). Note: the first run may remediate nothing until the
    initial management-group compliance scan completes (~30 min after assignment).
    For immediate backfill use scripts/Enable-AksPolicyAddon.ps1. Re-trigger later
    with: terraform apply -replace=azurerm_management_group_policy_remediation.aks_policy_addon[0]
  EOT
  default     = true
}

variable "remediation_role_definition_ids" {
  type        = list(string)
  description = <<-EOT
    Built-in role definition GUIDs granted to the assignment's managed identity.
    These MUST match the policy definition's roleDefinitionIds. Defaults are the
    two roles the AKS Policy add-on DeployIfNotExists policy requires; re-verify
    against the built-in definition if Microsoft ever revises the policy.
  EOT
  default = [
    "ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8", # Azure Kubernetes Service Contributor Role
    "18ed5180-3e48-46fd-8541-4ea054d57064", # Azure Kubernetes Service Policy Add-on Deployment
  ]
}
