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

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "helm_release" "istio-ingress" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = "1.13.3"
  verify     = false
  wait       = true

  values = ["${file("${path.module}/values.yaml")}"]

  depends_on = [
    kubernetes_namespace.namespace
  ]
}

data "kubernetes_service" "lb" {
  metadata {
    name      = var.release_name
    namespace = var.namespace
  }

  depends_on = [
    helm_release.istio-ingress
  ]
}