#-------------+----------------------------------------------------------------------------------+
# Script Name | outputs.tf                                                                       |
# Updated     | 2026-11-15                                                                       |
# Version     | 1.2                                                                              |
# VCF Version | 9.1.1.0-545627-2026-09                                                           |
# Description | Expose namespace and discovered inventory identifiers.                           |
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

output "namespace_name" {
  value = vsphere_namespace.namespace.name
}

output "namespace_id" {
  value = vsphere_namespace.namespace.id
}

output "supervisor_id" {
  value = vsphere_namespace.namespace.supervisor
}

output "storage_policy_ids" {
  value = vsphere_namespace.namespace.storage_policies
}
