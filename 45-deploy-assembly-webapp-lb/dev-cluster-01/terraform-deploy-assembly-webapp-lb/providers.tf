#----------------+----------------------------------------------------------------------------+
# Script Name    | providers.tf                                                               |
# Updated        | 2026-11-14                                                                 |
# Version        | 1.6                                                                        |
# VCF Version    | 9.1.1                                                                      |
# Description    | Configure Terraform requirements and the Kubernetes provider.              |
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
