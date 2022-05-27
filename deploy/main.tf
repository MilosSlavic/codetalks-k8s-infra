terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

resource "kubernetes_secret" "helm-secret" {
  metadata {
    name      = "helm-auth"
    namespace = "default"
  }

  data = {
    username = var.helm_username
    password : var.helm_password
  }
}