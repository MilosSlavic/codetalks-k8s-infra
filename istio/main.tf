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

resource "kubernetes_namespace" "istiosystem" {
  metadata {
    name = "istio-system"
  }
}

resource "helm_release" "istiobase" {
  name       = "istiobase"
  namespace  = "istio-system"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = "1.13.3"
  verify     = false

  depends_on = [
    kubernetes_namespace.istiosystem
  ]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  namespace  = "istio-system"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = "1.13.3"
  verify     = false
  wait       = true

  values = ["${file("${path.module}/values.yaml")}"]

  depends_on = [
    helm_release.istiobase
  ]
}