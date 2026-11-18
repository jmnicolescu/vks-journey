#-------------+------------------------------------------------------------------------------+
# Script Name | main.tf                                                                      |
# Updated     | 2026-11-14                                                                   |
# Version     | 1.2                                                                          |
# VCF Version | 9.1.1                                                                        |
# Description | Deploy MongoDB and Mongo Express with a LoadBalancer to dev-cluster-01.      |
#-------------+------------------------------------------------------------------------------+

#-------------+------------------------------------------------------------------------------+
# Requirement | Details                                                                      |
#-------------+------------------------------------------------------------------------------+
# Runtime     | Terraform >= 1.5.0 on Linux, macOS or Windows.                               |
# Provider    | hashicorp/kubernetes ~> 3.0; initialize before use.                          |
# Access      | Authenticated kubeconfig and workload Kubernetes API access.                 |
# Permissions | Manage the application namespace and its Kubernetes resources.               |
# Inputs      | Configure deployment values in terraform.tfvars.                             |
# Storage     | Existing storage class with dynamic volume provisioning.                     |
# Network     | Cluster image pulls and LoadBalancer provisioning.                           |
# Files       | Read kubeconfig; write Terraform working files and state.                    |
# State       | State contains application credentials; restrict file access.                |
#-------------+------------------------------------------------------------------------------+

# Create the application namespace.
resource "kubernetes_namespace_v1" "mongodb" {
  metadata {
    name = var.namespace
    labels = {
      "kubernetes.io/metadata.name"        = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Store MongoDB and Mongo Express credentials.
resource "kubernetes_secret_v1" "mongodb" {
  metadata {
    name      = "mongodb-secret"
    namespace = kubernetes_namespace_v1.mongodb.metadata[0].name
  }
  type = "Opaque"
  data = {
    mongo-root-username    = var.mongodb_username
    mongo-root-password    = var.mongodb_password
    mongo-express-password = var.mongo_express_password
  }
}

# Request persistent MongoDB storage; allow storage classes that wait for a consuming pod.
resource "kubernetes_persistent_volume_claim_v1" "mongodb" {
  metadata {
    name      = "mongodb-pvc"
    namespace = kubernetes_namespace_v1.mongodb.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = { storage = var.storage_size }
    }
  }
  wait_until_bound = false
}

# Deploy MongoDB with persistent storage.
resource "kubernetes_deployment_v1" "mongodb" {
  metadata {
    name      = "mongodb-deployment"
    namespace = kubernetes_namespace_v1.mongodb.metadata[0].name
    labels    = { app = "mongodb" }
  }
  spec {
    replicas = var.mongodb_replicas
    strategy {
      type = "Recreate"
    }
    selector {
      match_labels = { app = "mongodb" }
    }
    template {
      metadata {
        labels = { app = "mongodb" }
      }
      spec {
        container {
          name              = "mongodb"
          image             = var.mongodb_image
          image_pull_policy = "IfNotPresent"
          port {
            name           = "mongodb"
            container_port = var.mongodb_port
            protocol       = "TCP"
          }
          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mongodb.metadata[0].name
                key  = "mongo-root-username"
              }
            }
          }
          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mongodb.metadata[0].name
                key  = "mongo-root-password"
              }
            }
          }
          volume_mount {
            name       = "mongodb-storage"
            mount_path = "/data/db"
          }
          startup_probe {
            tcp_socket {
              port = "mongodb"
            }
            period_seconds    = 10
            failure_threshold = 30
          }
          readiness_probe {
            tcp_socket {
              port = "mongodb"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
          liveness_probe {
            tcp_socket {
              port = "mongodb"
            }
            initial_delay_seconds = 30
            period_seconds        = 20
          }
        }
        volume {
          name = "mongodb-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mongodb.metadata[0].name
          }
        }
      }
    }
  }
  wait_for_rollout = true
  timeouts {
    create = var.rollout_timeout
    update = var.rollout_timeout
  }
}

# Expose MongoDB inside the cluster.
resource "kubernetes_service_v1" "mongodb" {
  metadata {
    name      = "mongodb-service"
    namespace = kubernetes_namespace_v1.mongodb.metadata[0].name
    labels    = { app = "mongodb" }
  }
  spec {
    type     = "ClusterIP"
    selector = { app = "mongodb" }
    port {
      name        = "mongodb"
      protocol    = "TCP"
      port        = var.mongodb_port
      target_port = "mongodb"
    }
  }
}

# Publish the MongoDB connection settings.
resource "kubernetes_config_map_v1" "mongodb" {
  metadata {
    name      = "mongodb-configmap"
    namespace = kubernetes_namespace_v1.mongodb.metadata[0].name
  }
  data = {
    database_url  = kubernetes_service_v1.mongodb.metadata[0].name
    database_host = kubernetes_service_v1.mongodb.metadata[0].name
    database_port = tostring(var.mongodb_port)
    database_uri  = "mongodb://${kubernetes_service_v1.mongodb.metadata[0].name}:${var.mongodb_port}"
  }
}

# Deploy Mongo Express after MongoDB is ready.
resource "kubernetes_deployment_v1" "mongo_express" {
  metadata {
    name      = "mongo-express-deployment"
    namespace = kubernetes_namespace_v1.mongodb.metadata[0].name
    labels    = { app = "mongo-express" }
  }
  spec {
    replicas = var.mongo_express_replicas
    selector {
      match_labels = { app = "mongo-express" }
    }
    template {
      metadata {
        labels = { app = "mongo-express" }
      }
      spec {
        container {
          name              = "mongo-express"
          image             = var.mongo_express_image
          image_pull_policy = "IfNotPresent"
          port {
            name           = "http"
            container_port = var.mongo_express_port
            protocol       = "TCP"
          }
          env {
            name = "ME_CONFIG_MONGODB_ADMINUSERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mongodb.metadata[0].name
                key  = "mongo-root-username"
              }
            }
          }
          env {
            name = "ME_CONFIG_MONGODB_ADMINPASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mongodb.metadata[0].name
                key  = "mongo-root-password"
              }
            }
          }
          env {
            name = "ME_CONFIG_MONGODB_SERVER"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map_v1.mongodb.metadata[0].name
                key  = "database_url"
              }
            }
          }
          env {
            name  = "ME_CONFIG_MONGODB_PORT"
            value = tostring(var.mongodb_port)
          }
          env {
            name  = "ME_CONFIG_MONGODB_ENABLE_ADMIN"
            value = "true"
          }
          env {
            name  = "ME_CONFIG_BASICAUTH"
            value = "true"
          }
          env {
            name  = "ME_CONFIG_BASICAUTH_USERNAME"
            value = var.mongo_express_username
          }
          env {
            name = "ME_CONFIG_BASICAUTH_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.mongodb.metadata[0].name
                key  = "mongo-express-password"
              }
            }
          }
          startup_probe {
            tcp_socket {
              port = "http"
            }
            period_seconds    = 10
            failure_threshold = 30
          }
          readiness_probe {
            tcp_socket {
              port = "http"
            }
            period_seconds = 10
          }
          liveness_probe {
            tcp_socket {
              port = "http"
            }
            period_seconds = 20
          }
        }
      }
    }
  }
  depends_on       = [kubernetes_deployment_v1.mongodb]
  wait_for_rollout = true
  timeouts {
    create = var.rollout_timeout
    update = var.rollout_timeout
  }
}

# Expose Mongo Express through a LoadBalancer.
resource "kubernetes_service_v1" "mongo_express" {
  metadata {
    name      = "mongo-express-service"
    namespace = kubernetes_namespace_v1.mongodb.metadata[0].name
    labels    = { app = "mongo-express" }
  }
  spec {
    type     = "LoadBalancer"
    selector = { app = "mongo-express" }
    port {
      name        = "http"
      protocol    = "TCP"
      port        = var.mongo_express_port
      target_port = "http"
    }
  }
  wait_for_load_balancer = true
  timeouts {
    create = var.load_balancer_timeout
  }
}
