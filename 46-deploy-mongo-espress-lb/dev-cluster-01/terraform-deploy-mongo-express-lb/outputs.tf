#-------------+------------------------------------------------------------------------------+
# Script Name | outputs.tf                                                                   |
# Updated     | 2026-11-14                                                                   |
# Version     | 1.2                                                                          |
# VCF Version | 9.1.1                                                                        |
# Description | Report the Mongo Express LoadBalancer IP address and URL for dev-cluster-01. |
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

output "load_balancer_ip" {
  description = "Assigned Mongo Express LoadBalancer IP address."
  value       = kubernetes_service_v1.mongo_express.status[0].load_balancer[0].ingress[0].ip
}

output "app_url" {
  description = "Mongo Express URL."
  value       = "http://${kubernetes_service_v1.mongo_express.status[0].load_balancer[0].ingress[0].ip}:${var.mongo_express_port}"
}
