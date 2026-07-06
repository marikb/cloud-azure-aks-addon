# Tests that variable validation rejects bad input.
# Each run supplies an invalid value and expects that variable's validation to fail.

mock_provider "azurerm" {}
mock_provider "azuread" {}
mock_provider "random" {}

run "rejects_invalid_upgrade_channel" {
  command = plan

  variables {
    automatic_channel_upgrade = "weekly"
  }

  expect_failures = [
    var.automatic_channel_upgrade,
  ]
}

run "rejects_out_of_range_max_count" {
  command = plan

  variables {
    system_node_max_count = 0
  }

  expect_failures = [
    var.system_node_max_count,
  ]
}

run "rejects_invalid_maintenance_hour" {
  command = plan

  variables {
    maintenance_hours = [25]
  }

  expect_failures = [
    var.maintenance_hours,
  ]
}

run "rejects_full_patch_kubernetes_version" {
  command = plan

  variables {
    kubernetes_version = "1.30.5"
  }

  expect_failures = [
    var.kubernetes_version,
  ]
}
