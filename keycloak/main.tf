terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.5.0"
    }
  }
}

resource "helm_release" "keycloak" {
  name      = "keycloak"
  namespace = "default"
  chart     = "https://charts.bitnami.com/bitnami/keycloak-8.0.2.tgz"

  values = ["${file("${path.module}/values.yaml")}"]
}