terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

locals {
  name = "grafana"
}

resource "kubernetes_service_account" "sa" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
  }
}

resource "kubernetes_config_map" "cm" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
  }

  data = {
    "grafana.ini"             = "${file("${path.module}/grafana.ini")}"
    "datasources.yaml"        = "${file("${path.module}/datasources.yaml")}"
    "dashboardproviders.yaml" = "${file("${path.module}/dashboardproviders.yaml")}"
  }
}

resource "kubernetes_config_map" "istio_services_grafana_dashboards" {
  metadata {
    name      = "istio-services-grafana-dashboards"
    namespace = var.istio_ns
  }

  data = {
    "istio-mesh-dashboard.json"     = "${file("${path.module}/istio-mesh-dashboard.json")}"
    "istio-service-dashboard.json"  = "${file("${path.module}/istio-service-dashboard.json")}"
    "istio-workload-dashboard.json" = "${file("${path.module}/istio-workload-dashboard.json")}"
  }
}

resource "kubernetes_config_map" "istio_grafana_dashboards" {
  metadata {
    name      = "istio-grafana-dashboards"
    namespace = var.istio_ns
  }

  data = {
    "istio-performance-dashboard.json"   = "${file("${path.module}/istio-performance-dashboard.json")}"
    "istio-control-plane-dashboard.json" = "${file("${path.module}/istio-control-plane-dashboard.json")}"
  }
}

resource "kubernetes_service" "svc" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
  }

  spec {
    type = "ClusterIP"
    port {
      name        = "service"
      port        = 3000
      protocol    = "TCP"
      target_port = 3000
    }

    selector = {
      "name"      = local.name
      "namespace" = var.istio_ns
    }
  }
}


resource "kubernetes_deployment" "deploy" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
  }

  spec {
    replicas               = 1
    revision_history_limit = 10
    selector {
      match_labels = {
        "name"      = local.name
        "namespace" = var.istio_ns
      }
    }

    strategy {
      type = "RollingUpdate"
    }

    template {
      metadata {
        labels = {
          "name"                    = local.name
          namespace                 = var.istio_ns
          app                       = "grafana"
          "sidecar.istio.io/inject" = "false"
        }
      }

      spec {
        service_account_name            = local.name
        automount_service_account_token = true
        security_context {
          fs_group     = 472
          run_as_group = 472
          run_as_user  = 472
        }

        enable_service_links = true

        container {
          name              = local.name
          image             = "grafana/grafana:8.3.1"
          image_pull_policy = "IfNotPresent"

          volume_mount {
            name       = "config"
            mount_path = "/etc/grafana/grafana.ini"
            sub_path   = "grafana.ini"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/grafana/provisioning/datasources/datasources.yaml"
            sub_path   = "datasources.yaml"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/grafana/provisioning/dashboards/dashboardproviders.yaml"
            sub_path   = "dashboardproviders.yaml"
          }

          volume_mount {
            name       = "storage"
            mount_path = "/var/lib/grafana"
          }

          volume_mount {
            name       = "dashboards-istio"
            mount_path = "/var/lib/grafana/dashboards/istio"
          }

          volume_mount {
            name       = "dashboards-istio-services"
            mount_path = "/var/lib/grafana/dashboards/istio-services"
          }

          port {
            name           = "service"
            container_port = 3000
            protocol       = "TCP"
          }

          port {
            name           = "grafana"
            container_port = 3000
            protocol       = "TCP"
          }

          env {
            name  = "GF_PATHS_DATA"
            value = "/var/lib/grafana/"
          }

          env {
            name  = "GF_PATHS_LOGS"
            value = "/var/log/grafana"
          }
          env {
            name  = "GF_PATHS_PLUGINS"
            value = "/var/lib/grafana/plugins"
          }
          env {
            name  = "GF_PATHS_PROVISIONING"
            value = "/etc/grafana/provisioning"
          }
          env {
            name  = "GF_PATHS_DATA"
            value = "/var/lib/grafana/"
          }

          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "true"
          }

          env {
            name  = "GF_AUTH_ANONYMOUS_ORG_ROLE"
            value = "Admin"
          }

          env {
            name  = "GF_AUTH_BASIC_ENABLED"
            value = "false"
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "-"
          }

          env {
            name  = "GF_SECURITY_ADMIN_USER"
            value = "-"
          }

          liveness_probe {
            failure_threshold = 10
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 60
            timeout_seconds       = 30
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
          }

          resources {
            requests = {
              "cpu"    = "500m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "500m"
              "memory" = "1Gi"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = local.name
          }
        }

        volume {
          name = "dashboards-istio"
          config_map {
            name = "istio-grafana-dashboards"
          }
        }

        volume {
          name = "dashboards-istio-services"
          config_map {
            name = "istio-services-grafana-dashboards"
          }
        }

        volume {
          name = "storage"
          empty_dir {

          }
        }
      }
    }
  }
}