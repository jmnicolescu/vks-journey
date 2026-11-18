#---------------+------------------------------------------------------------------------------------+
# Script Name   | variables.tf                                                                       |
# Updated       | 2026-11-12                                                                         |
# Version       | 1.2                                                                                |
# VCF Version   | 9.1.1                                                                              |
# Description   | Declare vCenter user and access settings.                                          |
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
# Configuration | Supply all declared inputs through terraform.tfvars.                               |
#---------------+------------------------------------------------------------------------------------+

variable "vcenter" {
  type        = string
  description = "vCenter hostname."
}

variable "vcenter_user" {
  type        = string
  description = "SSO administrator used to create users and assign Supervisor permissions."
}

variable "vcenter_password" {
  type        = string
  description = "SSO administrator password."
  sensitive   = true
}

variable "insecure_tls" {
  type        = bool
  description = "Allow the lab vCenter certificate without verification."
}

variable "sso_domain" {
  type        = string
  description = "Local vCenter SSO domain."
}

variable "lab_user" {
  type        = string
  description = "Name of the lab user."
}

variable "lab_user_password" {
  type        = string
  description = "Initial password for the lab user; existing passwords are preserved."
  sensitive   = true
}

variable "lab_user_group" {
  type        = string
  description = "Lab group managed by Terraform; membership is authoritative."
}

variable "lab_admin" {
  type        = string
  description = "Name of the lab administrator."
}

variable "lab_admin_password" {
  type        = string
  description = "Initial password for the lab administrator; existing passwords are preserved."
  sensitive   = true
}

variable "lab_admin_group" {
  type        = string
  description = "Lab administrator group managed by Terraform; membership is authoritative."
}

variable "lab_admin_role" {
  type        = string
  description = "Existing role display label for root inventory access."
}

variable "supervisor_role" {
  type        = string
  description = "Existing role display label for Supervisor folder access."
}

variable "sso_admin_group" {
  type        = string
  description = "Existing SSO administrator group; other members are retained."
}

variable "sso_provider_group" {
  type        = string
  description = "Existing group already assigned SupervisorProviderAdministrator."
}

variable "supervisor_folder" {
  type        = string
  description = "Existing Supervisor inventory folder path."
}

