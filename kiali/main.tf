terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

locals {
  name = "kiali"
}

resource "kubernetes_service_account" "sa" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
    labels = {
      "app" = local.name
    }
  }
}

resource "kubernetes_config_map" "cm" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
    labels = {
      "app" = local.name
    }
  }

  data = {
    "config.yaml" = "${file("${path.module}/config.yaml")}"
  }
}


resource "kubernetes_cluster_role" "cr_viewer" {
  metadata {
    name = "kiali-viewer"
    labels = {
      "app" = local.name
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "endpoints", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "replicationcontrollers", "services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create", "post"]
  }

  rule {
    api_groups = ["extensions", "apps"]
    resources  = ["daemonsets", "deployments", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.istio.io", "security.istio.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["iter8.tools"]
    resources  = ["experiments"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenreviews"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role" "cr" {
  metadata {
    name = local.name
    labels = {
      "app" = local.name
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "endpoints", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "replicationcontrollers", "services"]
    verbs      = ["get", "list", "watch", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create", "post"]
  }

  rule {
    api_groups = ["extensions", "apps"]
    resources  = ["daemonsets", "deployments", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch", "patch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["cronjobs", "jobs"]
    verbs      = ["get", "list", "watch", "patch"]
  }

  rule {
    api_groups = ["networking.istio.io", "security.istio.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = ["iter8.tools"]
    resources  = ["experiments"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenreviews"]
    verbs      = ["create"]
  }
}

resource "kubernetes_cluster_role_binding" "crb_kiali" {
  metadata {
    name = local.name
    labels = {
      app = local.name
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.name
    namespace = var.istio_ns
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = local.name
  }
}

resource "kubernetes_role" "role_kiali_controlplane" {
  metadata {
    name      = "kiali-controlplane"
    namespace = var.istio_ns
    labels = {
      app = local.name
    }
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["list"]
  }

  rule {
    api_groups     = [""]
    resource_names = ["cacerts", "istio-ca-secret"]
    resources      = ["secrets"]
    verbs          = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "rb" {
  metadata {
    name      = "kiali-controlplane"
    namespace = var.istio_ns
    labels = {
      app = local.name
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.name
    namespace = var.istio_ns
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "kiali-controlplane"
  }
}

resource "kubernetes_service" "svc" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
    labels = {
      "app" = local.name
    }
  }

  spec {
    port {
      name     = "http"
      protocol = "TCP"
      port     = 20001
    }

    port {
      name     = "http-metrics"
      protocol = "TCP"
      port     = 9090
    }

    selector = {
      "name"    = local.name
      namespace = var.istio_ns
    }

  }
}

resource "kubernetes_deployment" "deploy" {
  metadata {
    name      = local.name
    namespace = var.istio_ns
    labels = {
      "app" = local.name
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = local.name
      }
    }

    strategy {
      rolling_update {
        max_surge       = 1
        max_unavailable = 1
      }
      type = "RollingUpdate"
    }

    template {
      metadata {
        name = local.name
        labels = {
          "app"                     = local.name
          "sidecar.istio.io/inject" = "false"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9090"
          "kiali.io/dashboards" : "go,kiali"
        }
      }

      spec {
        service_account_name = local.name
        container {
          image             = "quay.io/kiali/kiali:v1.45"
          image_pull_policy = "Always"
          name              = local.name
          command = [
            "/opt/kiali/kiali",
            "-config",
            "/kiali-configuration/config.yaml"
          ]

          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
          }

          port {
            name           = "api-port"
            container_port = 20001
          }

          port {
            name           = "http-metrics"
            container_port = 9090
          }

          readiness_probe {
            http_get {
              path   = "/kiali/healthz"
              port   = "api-port"
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 30
          }

          liveness_probe {
            http_get {
              path   = "/kiali/healthz"
              port   = "api-port"
              scheme = "HTTP"
            }

            initial_delay_seconds = 5
            period_seconds        = 30
          }

          env {
            name = "ACTIVE_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "LOG_LEVEL"
            value = "info"
          }

          env {
            name  = "LOG_FORMAT"
            value = "text"
          }

          env {
            name  = "LOG_TIME_FIELD_FORMAT"
            value = "2006-01-02T15:04:05Z07:00"
          }

          env {
            name  = "LOG_SAMPLER_RATE"
            value = "1"
          }

          volume_mount {
            name       = "kiali-configuration"
            mount_path = "/kiali-configuration"
          }

          volume_mount {
            name       = "kiali-cert"
            mount_path = "/kiali-cert"
          }

          volume_mount {
            name       = "kiali-secret"
            mount_path = "/kiali-secret"
          }

          volume_mount {
            name       = "kiali-cabundle"
            mount_path = "/kiali-cabundle"
          }

          resources {
            limits = {
              "memory" = "1Gi"
            }
            requests = {
              "memory" = "64Mi"
              "cpu"    = "10m"
            }
          }
        }

        volume {
          name = "kiali-configuration"
          config_map {
            name = "kiali"
          }
        }

        volume {
          name = "kiali-cert"
          secret {
            secret_name = "istio.kiali-service-account"
            optional    = true
          }
        }

        volume {
          name = "kiali-secret"
          secret {
            secret_name = "kiali"
            optional    = true
          }
        }

        volume {
          name = "kiali-cabundle"
          secret {
            secret_name = "kiali-cabundle"
            optional    = true
          }
        }
      }
    }
  }
}
