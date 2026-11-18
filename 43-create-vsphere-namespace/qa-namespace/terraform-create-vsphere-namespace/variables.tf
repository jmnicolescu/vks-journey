#-------------+----------------------------------------------------------------------------------+
# Script Name | variables.tf                                                                     |
# Updated     | 2026-11-15                                                                       |
# Version     | 1.4                                                                              |
# VCF Version | 9.1.1.0-545627-2026-09                                                           |
# Description | Declare connection and namespace inputs.                                         |
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

variable "vcenter" {
  description = "vCenter hostname from VCENTER in 00-vcf9-env.sh."
  type        = string
}

variable "vcenter_user" {
  description = "vCenter account for native namespace operations and inventory discovery."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "vcenter_password" {
  description = "vCenter password for native namespace operations and inventory discovery."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "insecure_tls" {
  description = "Lab TLS setting copied from VC_INSECURE; false requires trusted certificates."
  type        = bool
}

variable "namespace_name" {
  description = "Namespace name."
  type        = string
}

variable "supervisor_name" {
  description = "Supervisor name."
  type        = string
}

variable "storage_policy_names" {
  description = "Storage policy names."
  type        = list(string)
}

variable "content_library_names" {
  description = "Content library names."
  type        = list(string)
}

variable "vm_classes" {
  description = "Vm classes."
  type        = list(string)
}

variable "namespace_access" {
  description = "Direct namespace permissions; matches the access_list in scripts 01 and 03."
  type = list(object({
    domain       = string
    subject      = string
    subject_type = string
    role         = string
  }))
}

variable "cpu_limit_mhz" {
  description = "Namespace CPU limit in MHz."
  type        = number
}

variable "memory_limit_mib" {
  description = "Namespace memory limit in MiB."
  type        = number
}

# Set the storage quota in MiB for the namespace and each assigned policy.
variable "storage_limit_mib" {
  description = "Storage quota for the namespace and each assigned storage policy in MiB."
  type        = number
}
