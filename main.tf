provider "azurerm" {
  features {}
}

data "azurerm_kubernetes_cluster" "default" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

data "azurerm_storage_account" "proto_sa" {
  name                = "codetalksprotostorage"
  resource_group_name = "codetalks-proto"
}

data "azurerm_container_registry" "acr"{
name                = "codetalksacr"
  resource_group_name = "codetalks-rg"
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.default.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
}

provider "kubectl" {
  load_config_file       = false
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

module "fluxcd" {
  source = "./flux"
}

module "prometheus" {
  source = "./prometheus"

  istio_ns = "istio-system"
  depends_on = [
    module.istio
  ]
}

module "grafana" {
  source = "./grafana"

  istio_ns = "istio-system"
  depends_on = [
    module.istio
  ]
}

module "kiali" {
  source = "./kiali"

  istio_ns = "istio-system"
  depends_on = [
    module.istio
  ]
}

module "keycloak" {
  source = "./keycloak"

  depends_on = [
    module.istio
  ]
}

module "efk" {
  source = "./efk"
}

module "jaeger" {
  source = "./jaeger"

  depends_on = [
    module.istio
  ]
}

module "mssql" {
  source = "./mssql"

  depends_on = [
    module.istio
  ]
}

module "appcfg" {
  source = "./appcfg"

  employeedb  = "Server=mssql;Database=EmployeeDb;User Id=sa;Password=P@ssw0rd"
  knowledgedb = "Server=mssql;Database=KnowledgeDb;User Id=sa;Password=P@ssw0rd"
}

resource "kubernetes_secret" "image_pull_secret" {
  metadata{
    name = "acr"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths ={
        "codetalksacr.azurecr.io" = {
          "username" = data.azurerm_container_registry.acr.admin_username
          "passowrd" =data.azurerm_container_registry.acr.admin_password
          "email" = "m@s.com"
          "auth"     = base64encode("${data.azurerm_container_registry.acr.admin_username}:${data.azurerm_container_registry.acr.admin_password}")
        }
      }
    })
  }
}

module "protostorage"{
  source = "./protostorage"

  storage_account_name = data.azurerm_storage_account.proto_sa.name

  storage_account_key = data.azurerm_storage_account.proto_sa.primary_access_key
}