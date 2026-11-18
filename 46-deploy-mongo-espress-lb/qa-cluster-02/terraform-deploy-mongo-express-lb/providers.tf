#-------------+------------------------------------------------------------------------------+
# Script Name | providers.tf                                                                 |
# Updated     | 2026-11-14                                                                   |
# Version     | 1.2                                                                          |
# VCF Version | 9.1.1                                                                        |
# Description | Configure Terraform and the Kubernetes provider for dev-cluster-01.          |
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

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubernetes_context
}
