locals {
  cluster_name = "aks-${var.resource_group_name}"

  # data.azurerm_kubernetes_service_versions.current.latest_version returns a full
  # patch version (e.g. "1.30.5"). AKS patch auto-upgrade wants MAJOR.MINOR only,
  # so keep just the first two components. Padding with "0" guards against any
  # value that has fewer than two dot-separated parts.
  latest_minor       = join(".", slice(concat(split(".", data.azurerm_kubernetes_service_versions.current.latest_version), ["0", "0"]), 0, 2))
  kubernetes_version = coalesce(var.kubernetes_version, local.latest_minor)

  common_tags = {
    Environment = var.environment
    Application = var.application
  }
}
