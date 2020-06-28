variable "client_id" {}
variable "client_secret" {}

variable "agent_count" {
    default = 3
}

variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
}

variable "dns_prefix" {
    default = "exampleaks1"
}

variable cluster_name {
    default = "cluster-aks01"
}

variable resource_group_name {
    default = "aks-rg"
}

variable location {
    default = "West Europe"
}

variable Environment_tag {
    default = "Dev"
}

variable Application_tag {
    default = "AKS App <Name>"
}

variable log_analytics_workspace_name {
    default = "testLogAnalyticsWorkspaceName"
}

variable log_analytics_workspace_location {
    default = "westeurope"
}

variable log_analytics_workspace_sku {
    default = "PerGB2018"
}