resource "azuread_group" "aks_administrators" {
  display_name     = "${local.cluster_name}-administrators"
  description      = "Kubernetes administrators for the ${local.cluster_name} cluster."
  security_enabled = true
}
