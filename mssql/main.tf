terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

resource "kubernetes_storage_class" "mssql_sc" {
  metadata {
    name = "mssql-disk"
  }

  storage_provisioner = "kubernetes.io/azure-disk"
  parameters = {
    storageaccounttype = "Standard_LRS"
    kind               = "Managed"
  }

  reclaim_policy         = "Retain"
  allow_volume_expansion = true
}

resource "kubernetes_persistent_volume_claim" "mssql_pvc" {
  metadata {
    name      = "mssql-data"
    namespace = "default"
    annotations = {
      "volume.beta.kubernetes.io/storage-class" = "mssql-disk"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        "storage" = "20Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "mssql_deploy" {
  metadata {
    name      = "mssql"
    namespace = "default"
    labels = {
      app = "mssql"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mssql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mssql"
        }
      }

      spec {
        termination_grace_period_seconds = 30
        hostname                         = "mssql"
        security_context {
          fs_group = 10001
        }

        container {
          name  = "mssql"
          image = "mcr.microsoft.com/mssql/server:2019-latest"

          port {
            container_port = 1433
            protocol       = "TCP"
            name           = "tcp"
          }

          env {
            name  = "MSSQL_PID"
            value = "Developer"
          }

          env {
            name  = "ACCEPT_EULA"
            value = "Y"
          }

          env {
            name  = "SA_PASSWORD"
            value = "P@ssw0rd"
          }

          volume_mount {
            name       = "mssqldb"
            mount_path = "/var/opt/mssql"
          }
        }

        volume {
          name = "mssqldb"
          persistent_volume_claim {
            claim_name = "mssql-data"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mssql_svc" {
  metadata {
    name      = "mssql"
    namespace = "default"
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "mssql"
    }

    port {
      protocol    = "TCP"
      port        = 1433
      target_port = 1433
      name        = "tcp"
    }
  }
}