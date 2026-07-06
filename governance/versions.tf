terraform {
  # 1.7.0+ is required for the mock_provider blocks used by the test suite.
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.117"
    }
  }
}
