#----------------+----------------------------------------------------------------------------+
# Script Name    | variables.tf                                                               |
# Updated        | 2026-11-14                                                                 |
# Version        | 1.3                                                                        |
# VCF Version    | 9.1.1                                                                      |
# Description    | Declare inputs for the Assembly WebApp LoadBalancer deployment.            |
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

variable "kubeconfig_path" {
  description = "Path to the authenticated kubeconfig."
  type        = string
}

variable "kubernetes_context" {
  description = "Workload cluster Kubernetes context."
  type        = string
}

variable "namespace" {
  description = "Application namespace."
  type        = string
}

variable "app_name" {
  description = "Application label and container name."
  type        = string
}

variable "deployment_name" {
  description = "Deployment name."
  type        = string
}

variable "service_name" {
  description = "LoadBalancer service name."
  type        = string
}

variable "image" {
  description = "Container image."
  type        = string
}

variable "replicas" {
  description = "Number of application replicas."
  type        = number
}

variable "port" {
  description = "Container and service port."
  type        = number
}

variable "rollout_timeout" {
  description = "Deployment rollout timeout."
  type        = string
}

variable "load_balancer_timeout" {
  description = "LoadBalancer assignment timeout."
  type        = string
}
