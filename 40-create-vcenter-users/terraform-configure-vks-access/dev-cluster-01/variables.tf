#-------------+--------------------------------------------------------------+
# Script Name | variables.tf                                                 |
# Updated     | 2026-11-12                                                   |
# Version     | 1.0                                                          |
# VCF Version | 9.1.1                                                        |
# Description | Declare workload context, namespace and SSO group inputs.    |
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

variable "kubeconfig_path" {
  description = "Path to the kubeconfig containing administrator credentials."
  type        = string
}

variable "kubeconfig_context" {
  description = "Administrator context for the existing VKS workload cluster."
  type        = string
}

variable "kubernetes_namespace" {
  description = "Existing Kubernetes namespace in which to grant view access."
  type        = string
}

variable "lab_user_group" {
  description = "SSO group receiving read-only workload access."
  type        = string
}

variable "sso_domain" {
  description = "SSO domain of the group."
  type        = string
}
