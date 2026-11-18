#-------------+----------------------------------------------------------------------------------+
# Script Name | providers.tf                                                                     |
# Updated     | 2026-11-15                                                                       |
# Version     | 1.2                                                                              |
# VCF Version | 9.1.1.0-545627-2026-09                                                           |
# Description | Configure Terraform and providers for the QA namespace.                         |
#-------------+----------------------------------------------------------------------------------+

#-------------+----------------------------------------------------------------------------------+
# Requirement | Details                                                                          |
#-------------+----------------------------------------------------------------------------------+
# Runtime     | Terraform >= 1.10.0 on macOS, Linux or Windows.                                  |
# Providers   | vmware/vsphere = 2.17.1; magodo/restful = 0.25.2.                                |
# Inputs      | terraform.tfvars and the Terraform files in this directory.                      |
# Access      | HTTPS to vCenter; inventory read and namespace management permissions.           |
# Resources   | Existing Supervisor, storage policies, VM classes and access principals.         |
#-------------+----------------------------------------------------------------------------------+

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    restful = {
      source  = "magodo/restful"
      version = "= 0.25.2"
    }
    vsphere = {
      source  = "vmware/vsphere"
      version = "= 2.17.1"
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
