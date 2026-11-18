#----------------+--------------------------------------------------------------+
# Script Name    | outputs.tf                                                   |
# Updated        | 2026-11-15                                                   |
# Version        | 1.5                                                          |
# VCF Version    | 9.1.1.0-545627-2026-09                                       |
# Description    | Expose the VKS Cluster identity and manifest paths.          |
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

output "cluster_name" {
  value = kubernetes_manifest.cluster.object.metadata.name
}

output "namespace" {
  value = kubernetes_manifest.cluster.object.metadata.namespace
}

output "manifest_yaml" {
  description = "Reusable Cluster YAML generated from the desired manifest."
  value       = yamlencode(local.cluster_manifest)
}

output "manifest_file" {
  description = "Path to the reusable Cluster YAML in deployment-files."
  value       = local_file.cluster_manifest.filename
}
