provider "azurerm" {
  features {}
}

data "azurerm_kubernetes_cluster" "default" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
  }
}

resource "kubernetes_labels" "default-injection" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "default"
  }

  labels = {
    "istio-injection" = "enabled"
  }
}

module "istio" {
  source = "./istio"

  depends_on = [
    kubernetes_labels.default-injection
  ]
}

module "istio-ingressgateway" {
  source = "./ingressgateway"

  release_name = "istio-ingressgateway"
  namespace    = "istio-ingress"

  depends_on = [
    module.istio
  ]
}