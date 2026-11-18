#-------------+-----------------------------------------------------------------------------------+
# Script Name | variables.tf                                                                      |
# Updated     | 2026-11-15                                                                        |
# Version     | 1.3                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                            |
# Description | Declare connection and namespace inputs for the DEV configuration.                |
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

variable "vcenter" {
  description = "vCenter hostname."
  type        = string
}

variable "vcenter_user" {
  description = "vCenter account for inventory discovery and automatic session login."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "vcenter_password" {
  description = "vCenter password for inventory discovery and automatic session login."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "insecure_tls" {
  description = "Skip TLS verification for the lab; false requires trusted certificates."
  type        = bool
}

variable "namespace_name" {
  description = "Namespace name."
  type        = string
}

variable "description" {
  description = "Description."
  type        = string
}

variable "datacenter_name" {
  description = "Datacenter name."
  type        = string
}

variable "cluster_name" {
  description = "Cluster name."
  type        = string
}

variable "storage_policy_names" {
  description = "Storage policy names."
  type        = list(string)
}

variable "cpu_limit_mhz" {
  description = "Namespace CPU limit in MHz."
  type        = number
}

variable "memory_limit_mib" {
  description = "Namespace memory limit in MiB."
  type        = number
}

variable "storage_limit_mib" {
  description = "Storage request limit for the namespace and limit for each policy in MiB."
  type        = number
}

variable "vm_classes" {
  description = "Vm classes."
  type        = list(string)
}

variable "namespace_access" {
  description = "Direct namespace access permissions."
  type = list(object({
    domain       = string
    subject      = string
    subject_type = string
    role         = string
  }))
}
