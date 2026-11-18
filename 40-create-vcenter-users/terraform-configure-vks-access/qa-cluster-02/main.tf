#-------------+--------------------------------------------------------------+
# Script Name | main.tf                                                      |
# Updated     | 2026-11-12                                                   |
# Version     | 1.0                                                          |
# VCF Version | 9.1.1                                                        |
# Description | Grant LabUsers read-only access within a workload namespace. |
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

# Grant the SSO group view access only within the configured Kubernetes namespace.
resource "kubernetes_role_binding_v1" "lab_users_view" {
  metadata {
    name      = "labusers-view"
    namespace = var.kubernetes_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = "sso:${var.lab_user_group}@${var.sso_domain}"
  }
}
