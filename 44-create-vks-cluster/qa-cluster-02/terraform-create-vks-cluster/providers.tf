#----------------+--------------------------------------------------------------+
# Script Name    | providers.tf                                                 |
# Updated        | 2026-11-15                                                   |
# Version        | 1.2                                                          |
# VCF Version    | 9.1.1.0-545627-2026-09                                       |
# Description    | Configure Terraform providers and Supervisor access.         |
#----------------+--------------------------------------------------------------+

#----------------+--------------------------------------------------------------+
# Requirement    | Details                                                      |
#----------------+--------------------------------------------------------------+
# Runtime        | Terraform >= 1.5.0; Kubernetes ~> 3.0; local ~> 2.5.         |
# Inputs         | Deployment settings in terraform.tfvars.                     |
# Access         | Authenticated Supervisor kubeconfig and Cluster permissions. |
# Infrastructure | Existing namespace, VM/storage classes and VKS ClusterClass. |
# Behavior       | Waits for Cluster availability and Cluster deletion.        |
#----------------+--------------------------------------------------------------+

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.supervisor_context
}

