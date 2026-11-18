#-------------+--------------------------------------------------------------+
# Script Name | providers.tf                                                 |
# Updated     | 2026-11-12                                                   |
# Version     | 1.0                                                          |
# VCF Version | 9.1.1                                                        |
# Description | Configure Kubernetes access using an administrator context.  |
#-------------+--------------------------------------------------------------+

#-------------+--------------------------------------------------------------+
# Requirement | Details                                                      |
#-------------+--------------------------------------------------------------+
# Runtime     | Terraform >= 1.10.0 on macOS, Linux or Windows.              |
# Provider    | hashicorp/kubernetes 2.38.0; run terraform init.             |
# Inputs      | terraform.tfvars and companion .tf files in this directory.  |
# Access      | Existing VKS cluster and administrator kubeconfig context.   |
# Target      | Existing Kubernetes namespace; SSO group has namespace VIEW. |
# Scope       | Grant Kubernetes view only; no VKS lifecycle permissions.    |
#-------------+--------------------------------------------------------------+

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.38.0"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kubeconfig_context
}
