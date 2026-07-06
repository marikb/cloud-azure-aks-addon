# Resolves the latest available Kubernetes version in the target region.
# include_preview = false keeps latest_version aligned with the GA versions that
# the "patch" upgrade channel will actually roll out to.
data "azurerm_kubernetes_service_versions" "current" {
  location        = var.location
  include_preview = false
}
