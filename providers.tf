terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.11.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.5.0"
    }
  }
}