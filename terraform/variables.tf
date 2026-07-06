variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "westeurope"

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group created for the AKS cluster."
  default     = "aks-app"
}

variable "environment" {
  type        = string
  description = "Value of the Environment tag applied to all resources."
  default     = "Staging"
}

variable "application" {
  type        = string
  description = "Value of the Application tag applied to all resources."
  default     = "aks-app"
}

variable "kubernetes_version" {
  type        = string
  description = <<-EOT
    Kubernetes version as MAJOR.MINOR only (e.g. "1.30"). Leave null to track the
    latest GA minor available in the region. When automatic_channel_upgrade = "patch"
    the value must be major.minor (never a full major.minor.patch).
  EOT
  default     = null

  validation {
    condition     = var.kubernetes_version == null || can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must be null or a MAJOR.MINOR string such as \"1.30\"."
  }
}

variable "automatic_channel_upgrade" {
  type        = string
  description = "AKS automatic upgrade channel."
  default     = "patch"

  validation {
    condition     = contains(["patch", "rapid", "node-image", "stable", "none"], var.automatic_channel_upgrade)
    error_message = "automatic_channel_upgrade must be one of: patch, rapid, node-image, stable, none."
  }
}

variable "system_node_vm_size" {
  type        = string
  description = "VM size for the system node pool."
  default     = "Standard_DS2_v2"
}

variable "system_node_min_count" {
  type        = number
  description = "Minimum node count for the autoscaling system node pool."
  default     = 1

  validation {
    condition     = var.system_node_min_count >= 1
    error_message = "system_node_min_count must be at least 1."
  }
}

variable "system_node_max_count" {
  type        = number
  description = "Maximum node count for the autoscaling system node pool."
  default     = 3

  validation {
    condition     = var.system_node_max_count >= 1 && var.system_node_max_count <= 100
    error_message = "system_node_max_count must be between 1 and 100."
  }
}

variable "system_node_os_disk_size_gb" {
  type        = number
  description = "OS disk size (GB) for system node pool VMs."
  default     = 128
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to spread the system node pool across."
  default     = ["1", "2", "3"]
}

variable "node_max_surge" {
  type        = string
  description = "Max surge during node pool upgrades (integer or percentage, e.g. \"33%\")."
  default     = "33%"
}

variable "maintenance_day" {
  type        = string
  description = "Weekday for the AKS maintenance window (Sunday..Saturday)."
  default     = "Sunday"

  validation {
    condition     = contains(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], var.maintenance_day)
    error_message = "maintenance_day must be a capitalized weekday, e.g. \"Sunday\"."
  }
}

variable "maintenance_hours" {
  type        = list(number)
  description = "Hours (0-23) during which maintenance and upgrades may run."
  default     = [1, 2, 3]

  validation {
    condition     = length(var.maintenance_hours) > 0 && alltrue([for h in var.maintenance_hours : h >= 0 && h <= 23])
    error_message = "maintenance_hours must be a non-empty list of integers between 0 and 23."
  }
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics workspace retention in days (30-730)."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "azure_rbac_enabled" {
  type        = bool
  description = "Enable Azure RBAC for Kubernetes authorization, in addition to managed Azure AD integration."
  default     = false
}
