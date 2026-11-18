#---------------+------------------------------------------------------------------------------------+
# Script Name   | providers.tf                                                                       |
# Updated       | 2026-11-12                                                                         |
# Version       | 1.2                                                                                |
# VCF Version   | 9.1.1                                                                              |
# Description   | Configure vSphere and REST providers for SSO users and permissions.                |
#---------------+------------------------------------------------------------------------------------+

#---------------+------------------------------------------------------------------------------------+
# Requirement   | Details                                                                            |
#---------------+------------------------------------------------------------------------------------+
# Runtime       | Terraform >= 1.10.0 on macOS, Linux or Windows.                                    |
# Providers     | vmware/vsphere 2.17.1; magodo/restful 0.25.2.                                      |
# Inputs        | terraform.tfvars and companion .tf files in this directory.                        |
# Access        | HTTPS access to vCenter 9.1.1 with SSO administrator credentials.                  |
# Targets       | Existing Supervisor folder, roles and built-in SSO groups.                         |
# Local files   | Write access for Terraform data and state; protect credentials and state.          |
# Setup         | Run terraform init to install the pinned providers.                                |
#---------------+------------------------------------------------------------------------------------+

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "= 2.17.1"
    }
    restful = {
      source  = "magodo/restful"
      version = "= 0.25.2"
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.vcenter
  user                 = var.vcenter_user
  password             = var.vcenter_password
  allow_unverified_ssl = var.insecure_tls
}

provider "restful" {
  alias    = "session"
  base_url = "https://${var.vcenter}"
  client = {
    tls_insecure_skip_verify = var.insecure_tls
  }
}

provider "restful" {
  base_url = "https://${var.vcenter}"
  client = {
    tls_insecure_skip_verify = var.insecure_tls
  }
  header = {
    "vmware-api-session-id" = ephemeral.restful_resource.vcenter_session.sensitive_output
  }
}
