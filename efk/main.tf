terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

locals {
  namespace = "logging-system"
  cs_name   = "elasticsearch-disk"
  es_name   = "elasticsearch"
  kib_name  = "kibana"
  fb_name   = "fluentbit"
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = local.namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_storage_class" "disk" {
  metadata {
    name = local.cs_name
  }

  storage_provisioner = "disk.csi.azure.com"
  parameters = {
    "skuName" = "Standard_LRS"
  }
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
}

resource "kubernetes_persistent_volume_claim" "pvc" {
  metadata {
    name      = local.cs_name
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = local.cs_name
    resources {
      requests = {
        "storage" = "50Gi"
      }
    }
  }
  depends_on = [
    kubernetes_namespace.ns
  ]
}

resource "kubernetes_deployment" "elasticsearch" {
  metadata {
    name      = local.es_name
    namespace = local.namespace

    labels = {
      "app" = local.es_name
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "app" = local.es_name
      }
    }

    template {
      metadata {
        labels = {
          "app" = local.es_name
        }
      }

      spec {
        container {
          image = "docker.elastic.co/elasticsearch/elasticsearch:7.16.1"
          name  = local.es_name
          resources {
            requests = {
              "memory" = "256Mi"
              "cpu"    = "250m"
            }
            limits = {
              "memory" = "1Gi"
              "cpu"    = "500m"
            }
          }

          image_pull_policy = "IfNotPresent"
          env {
            name  = "discovery.type"
            value = "single-node"
          }

          env {
            name  = "ES_JAVA_OPTS"
            value = "-Xms512m -Xmx1g"
          }

          port {
            name           = "http"
            container_port = 9200
          }

          volume_mount {
            name       = local.cs_name
            mount_path = "/usr/share/elasticsearch/data/*/"
          }
        }

        volume {
          name = local.cs_name
          persistent_volume_claim {
            claim_name = local.cs_name
          }
        }
      }
    }

  }

  depends_on = [
    kubernetes_namespace.ns
  ]
}

resource "kubernetes_service" "elasticsearch" {
  metadata {
    name      = local.es_name
    namespace = local.namespace
  }

  spec {
    selector = {
      app = local.es_name
    }

    port {
      name        = "http"
      port        = 9200
      target_port = 9200
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_namespace.ns
  ]
}

# kibana
resource "kubernetes_deployment" "kibana" {
  metadata {
    name      = local.kib_name
    namespace = local.namespace

    labels = {
      app = local.kib_name
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = local.kib_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.kib_name
        }
      }

      spec {
        container {
          image             = "docker.elastic.co/kibana/kibana:7.16.1"
          name              = local.kib_name
          image_pull_policy = "IfNotPresent"

          env {
            name  = "SERVER_NAME"
            value = "logging-elasticsearch"
          }

          env {
            name  = "ELASTICSEARCH_HOSTS"
            value = "http://elasticsearch:9200/"
          }

          port {
            container_port = 5601
            name           = "http"
          }

          resources {
            requests = {
              "memory" = "256Mi"
              "cpu"    = "100m"
            }
            limits = {
              "memory" = "1Gi"
              "cpu"    = "500m"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.ns
  ]
}

resource "kubernetes_service" "kibana" {
  metadata {
    name      = local.kib_name
    namespace = local.namespace
    labels = {
      app = local.kib_name
    }
  }

  spec {
    selector = {
      app = local.kib_name
    }

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 5601
      target_port = 5601
    }
  }

  depends_on = [
    kubernetes_namespace.ns
  ]
}

# fluentbit
resource "kubernetes_service_account" "fluentbit_sa" {
  metadata {
    name      = local.fb_name
    namespace = local.namespace
  }

  depends_on = [
    kubernetes_namespace.ns
  ]
}

resource "kubernetes_cluster_role" "fluentbit_cr" {
  metadata {
    name = local.fb_name
    labels = {
      app = local.fb_name
    }
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "fluentbit_crb" {
  metadata {
    name = local.fb_name
    labels = {
      app = local.fb_name
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.fb_name
    namespace = local.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = local.fb_name
  }
}

resource "kubernetes_config_map" "fluentbit_cm" {
  metadata {
    name      = local.fb_name
    namespace = local.namespace
    labels = {
      app = local.fb_name
    }
  }

  data = {
    "fluent-bit.conf"           = "${file("${path.module}/fluent-bit.conf")}"
    "input-kubernetes.conf"     = "${file("${path.module}/input-kubernetes.conf")}"
    "filter-kubernetes.conf"    = "${file("${path.module}/filter-kubernetes.conf")}"
    "output-elasticsearch.conf" = "${file("${path.module}/output-elasticsearch.conf")}"
    "parsers.conf"              = "${file("${path.module}/parsers.conf")}"
  }

  depends_on = [
    kubernetes_namespace.ns
  ]
}

resource "kubernetes_daemonset" "fluentbit_daemonset" {
  metadata {
    name      = local.fb_name
    namespace = local.namespace
    labels = {
      app                             = local.fb_name
      "kubernetes.io/cluster-service" = "true"
    }
  }

  spec {
    selector {
      match_labels = {
        app = local.fb_name
      }
    }

    template {
      metadata {
        labels = {
          app                             = local.fb_name
          "kubernetes.io/cluster-service" = "true"
        }

        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "2020"
          "prometheus.io/path"   = "/api/v1/metrics/prometheus"
        }
      }

      spec {
        termination_grace_period_seconds = 10
        service_account_name             = local.fb_name

        container {
          name              = local.fb_name
          image             = "fluent/fluent-bit:1.5"
          image_pull_policy = "Always"


          env {
            name  = "FLUENT_ELASTICSEARCH_HOST"
            value = "elasticsearch"
          }

          env {
            name  = "FLUENT_ELASTICSEARCH_PORT"
            value = "9200"
          }

          port {
            name           = "fluentbit"
            container_port = 2020
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }

          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }

          volume_mount {
            name       = local.fb_name
            mount_path = "/fluent-bit/etc/"
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        volume {
          name = local.fb_name
          config_map {
            name = local.fb_name
          }
        }

        toleration {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        toleration {
          operator = "Exists"
          effect   = "NoExecute"
        }

        toleration {
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.ns
  ]
}
