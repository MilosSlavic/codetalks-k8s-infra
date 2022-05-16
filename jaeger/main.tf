terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

locals {
  name      = "jaeger"
  namespace = "istio-system"
}

resource "kubernetes_deployment" "deploy" {
  metadata {
    name      = local.name
    namespace = local.namespace
    labels = {
      app = local.name
    }
  }

  spec {
    selector {
      match_labels = {
        app = local.name
      }
    }

    template {
      metadata {
        labels = {
          app = local.name
        }
        annotations = {
          "sidecar.istio.io/inject" = "false"
          "prometheus.io/scrape"    = "true"
          "prometheus.io/port"      = "14269"
        }
      }

      spec {
        container {
          name  = local.name
          image = "docker.io/jaegertracing/all-in-one:1.29"
          env {
            name  = "BADGER_EPHEMERAL"
            value = "false"
          }
          env {
            name  = "SPAN_STORAGE_TYPE"
            value = "badger"
          }
          env {
            name  = "BADGER_DIRECTORY_VALUE"
            value = "/badger/data"
          }
          env {
            name  = "BADGER_DIRECTORY_KEY"
            value = "/badger/key"
          }
          env {
            name  = "COLLECTOR_ZIPKIN_HOST_PORT"
            value = ":9411"
          }
          env {
            name  = "MEMORY_MAX_TRACES"
            value = "50000"
          }
          env {
            name  = "QUERY_BASE_PATH"
            value = "/jaeger"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 14269
            }
          }
          readiness_probe {
            http_get {
              path = "/"
              port = 14269
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/badger"
          }
          resources {
            requests = {
              "cpu" = "10m"
            }
          }
        }

        volume {
          name = "data"
          empty_dir {

          }
        }
      }
    }
  }
}

resource "kubernetes_service" "jaeger_svc" {
  metadata {
    name      = "tracing"
    namespace = local.namespace
    labels = {
      app = local.name
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = local.name
    }

    port {
      name        = "http-query" #FRONTEND UI
      port        = 80
      protocol    = "TCP"
      target_port = 16686
    }

    port {
      name        = "grpc-query"
      port        = 16685
      protocol    = "TCP"
      target_port = 16685
    }
  }
}

resource "kubernetes_service" "zipkin_api" {
  metadata {
    name      = "zipkin"
    namespace = local.namespace
    labels = {
      name = "zipkin"
    }
  }

  spec {
    selector = {
      app = local.name
    }

    port {
      port        = 9441
      name        = "http-query"
      target_port = 9411
    }
  }
}

resource "kubernetes_service" "jaeger_collector" {
  metadata {
    name      = "jaeger-collector"
    namespace = local.namespace
    labels = {
      app = local.name
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = local.name
    }

    port {
      name        = "jaeger-collector-http"
      port        = 14268
      target_port = 14268
      protocol    = "TCP"
    }

    port {
      name        = "jaeger-collector-grpc"
      port        = 14250
      target_port = 14250
      protocol    = "TCP"
    }

    port {
      port        = 9411
      target_port = 9411
      name        = "http-zipkin"
    }
  }
}