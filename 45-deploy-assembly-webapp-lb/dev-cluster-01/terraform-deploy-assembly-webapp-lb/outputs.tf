#----------------+----------------------------------------------------------------------------+
# Script Name    | outputs.tf                                                                 |
# Updated        | 2026-11-14                                                                 |
# Version        | 1.6                                                                        |
# VCF Version    | 9.1.1                                                                      |
# Description    | Expose the Assembly WebApp LoadBalancer IP address and URL.                |
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

output "load_balancer_ip" {
  description = "Assigned LoadBalancer IP address."
  value       = kubernetes_service_v1.assembly.status[0].load_balancer[0].ingress[0].ip
}

output "app_url" {
  description = "Assembly WebApp URL."
  value       = "http://${kubernetes_service_v1.assembly.status[0].load_balancer[0].ingress[0].ip}:${var.port}"
}
