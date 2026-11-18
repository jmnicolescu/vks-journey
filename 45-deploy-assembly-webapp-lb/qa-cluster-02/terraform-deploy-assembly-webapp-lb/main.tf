#----------------+----------------------------------------------------------------------------+
# Script Name    | main.tf                                                                    |
# Updated        | 2026-11-14                                                                 |
# Version        | 1.6                                                                        |
# VCF Version    | 9.1.1                                                                      |
# Description    | Deploy the Assembly WebApp with a LoadBalancer service to dev-cluster-01.  |
#----------------+----------------------------------------------------------------------------+

#----------------+----------------------------------------------------------------------------+
# Requirement    | Details                                                                    |
#----------------+----------------------------------------------------------------------------+
# Runtime        | Terraform >= 1.5.0 on a supported workstation.                             |
# Provider       | hashicorp/kubernetes ~> 3.0; initialize with terraform init.               |
# Files          | All .tf files and terraform.tfvars from this directory.                    |
# Authentication | Authenticated kubeconfig selecting dev-cluster-01:dev-cluster-01.          |
# Access         | Cluster API connectivity and namespace/workload management permissions.    |
# Infrastructure | Existing VKS cluster with LoadBalancer support and container image access. |
# Local files    | Write access for Terraform state and provider installation.                |
#----------------+----------------------------------------------------------------------------+

# Create the application namespace.
resource "kubernetes_namespace_v1" "assembly" {
  metadata {
    name = var.namespace
    labels = {
      "kubernetes.io/metadata.name"        = var.namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Deploy the Assembly WebApp.
resource "kubernetes_deployment_v1" "assembly" {
  metadata {
    name      = var.deployment_name
    namespace = kubernetes_namespace_v1.assembly.metadata[0].name
    labels    = { app = var.app_name }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = { app = var.app_name }
    }

    template {
      metadata {
        name   = "${var.app_name}-pod"
        labels = { app = var.app_name }
      }

      spec {
        container {
          name              = var.app_name
          image             = var.image
          image_pull_policy = "Always"

          port {
            container_port = var.port
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

# Expose the application through a LoadBalancer.
resource "kubernetes_service_v1" "assembly" {
  metadata {
    name      = var.service_name
    namespace = kubernetes_namespace_v1.assembly.metadata[0].name
    labels    = { app = var.app_name }
  }

  spec {
    type     = "LoadBalancer"
    selector = { app = var.app_name }

    port {
      protocol    = "TCP"
      port        = var.port
      target_port = var.port
    }
  }

  wait_for_load_balancer = true

  timeouts {
    create = var.load_balancer_timeout
  }
}
