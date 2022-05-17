terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

resource "kubernetes_secret" "proto_secret" {
  metadata {
    name      = "protosecret"
    namespace = "default"
  }

  data = {
    azurestorageaccountname = var.storage_account_name
    azurestorageaccountkey  = var.storage_account_key
  }
}

resource "kubernetes_persistent_volume" "proto_pv" {
  metadata {
    name      = "protopv"
  }

  spec {
    capacity = {
      "storage" = "10Gi"
    }
    access_modes                     = ["ReadOnlyMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "azurefile-csi"
    persistent_volume_source {
      csi {
        driver        = "file.csi.azure.com"
        read_only     = true
        volume_handle = "protohandle"
        volume_attributes = {
          "shareName" = "protoshare"
        }
        node_stage_secret_ref {
          name      = "protosecret"
          namespace = "default"
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "proto_pvc" {
  metadata {
    name      = "protopvc"
    namespace = "default"
  }

  spec {
    access_modes       = ["ReadOnlyMany"]
    storage_class_name = "azurefile-csi"
    volume_name        = "protopv"
    resources {
      requests = {
        "storage" = "10Gi"
      }
    }
  }
}