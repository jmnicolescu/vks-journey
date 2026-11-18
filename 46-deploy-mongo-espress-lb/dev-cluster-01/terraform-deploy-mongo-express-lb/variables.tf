#-------------+------------------------------------------------------------------------------+
# Script Name | variables.tf                                                                 |
# Updated     | 2026-11-14                                                                   |
# Version     | 1.2                                                                          |
# VCF Version | 9.1.1                                                                        |
# Description | Declare MongoDB and Mongo Express deployment inputs for dev-cluster-01.      |
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

variable "storage_class" {
  description = "Existing storage class for MongoDB."
  type        = string
}

variable "storage_size" {
  description = "MongoDB persistent volume size."
  type        = string
}

variable "mongodb_image" {
  description = "MongoDB container image."
  type        = string
}

variable "mongodb_replicas" {
  description = "Number of MongoDB replicas sharing the persistent volume."
  type        = number
}

variable "mongodb_port" {
  description = "MongoDB container and service port."
  type        = number
}

variable "mongodb_username" {
  description = "MongoDB root username."
  type        = string
}

variable "mongodb_password" {
  description = "MongoDB root password."
  type        = string
  sensitive   = true
}

variable "mongo_express_image" {
  description = "Mongo Express container image."
  type        = string
}

variable "mongo_express_replicas" {
  description = "Number of Mongo Express replicas."
  type        = number
}

variable "mongo_express_port" {
  description = "Mongo Express container and service port."
  type        = number
}

variable "mongo_express_username" {
  description = "Mongo Express basic authentication username."
  type        = string
}

variable "mongo_express_password" {
  description = "Mongo Express basic authentication password."
  type        = string
  sensitive   = true
}

variable "rollout_timeout" {
  description = "Deployment rollout timeout."
  type        = string
}

variable "load_balancer_timeout" {
  description = "LoadBalancer assignment timeout."
  type        = string
}
