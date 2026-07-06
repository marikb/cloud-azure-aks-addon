output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.primary.name
}

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "kubernetes_version" {
  description = "Kubernetes version the cluster is pinned to (major.minor)."
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}

output "admin_group_object_id" {
  description = "Object ID of the Azure AD cluster-admin group."
  value       = azuread_group.aks_administrators.object_id
}

output "get_credentials_command" {
  description = "Azure CLI command to fetch kubeconfig credentials for the cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.primary.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}
