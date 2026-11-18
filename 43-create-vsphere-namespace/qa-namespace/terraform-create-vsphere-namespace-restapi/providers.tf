#-------------+-----------------------------------------------------------------------------------+
# Script Name | providers.tf                                                                      |
# Updated     | 2026-11-15                                                                        |
# Version     | 1.2                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                            |
# Description | Configure Terraform and providers for the QA namespace.                          |
#-------------+-----------------------------------------------------------------------------------+

#-------------+-----------------------------------------------------------------------------------+
# Requirement | Details                                                                           |
#-------------+-----------------------------------------------------------------------------------+
# Runtime     | Terraform >= 1.10.0 on macOS, Linux or Windows.                                   |
# Providers   | vmware/vsphere ~> 2.16; Mastercard/restapi ~> 2.0; magodo/restful ~> 0.25.2.      |
# Inputs      | terraform.tfvars, variables.tf and providers.tf in this directory.                |
# Access      | HTTPS to vCenter; inventory read and namespace management permissions.            |
# Resources   | Existing Supervisor-enabled cluster, storage policy, VM classes and access group. |
# Local files | Write access for provider initialization, lock file, plans and state.             |
#-------------+-----------------------------------------------------------------------------------+

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    restful = {
      source  = "magodo/restful"
      version = "~> 0.25.2"
    }
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.16"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}

provider "vsphere" {
  vsphere_server       = var.vcenter
  user                 = var.vcenter_user
  password             = var.vcenter_password
  allow_unverified_ssl = var.insecure_tls
}

provider "restapi" {
  uri                  = "https://${var.vcenter}"
  insecure             = var.insecure_tls
  timeout              = 120
  write_returns_object = false
  debug                = false
  headers = {
    "vmware-api-session-id" = ephemeral.restful_resource.vcenter_session.sensitive_output
    "Content-Type"          = "application/json"
  }
}

provider "restful" {
  base_url = "https://${var.vcenter}"
  client = {
    tls_insecure_skip_verify = var.insecure_tls
  }
}
