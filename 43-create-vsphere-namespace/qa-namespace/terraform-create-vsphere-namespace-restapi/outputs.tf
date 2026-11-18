#-------------+-----------------------------------------------------------------------------------+
# Script Name | outputs.tf                                                                        |
# Updated     | 2026-11-15                                                                        |
# Version     | 1.2                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                            |
# Description | Expose namespace identity, cluster ID, creation payload and observed status.      |
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

output "namespace_name" {
  value = restapi_object.namespace.id
}

output "cluster_id" {
  value = data.vsphere_compute_cluster.target.id
}

output "create_spec" {
  description = "Desired vCenter namespace CreateSpec, containing resolved inventory IDs."
  value       = local.create_spec
}

output "config_status" {
  description = "Last observed status; only RUNNING means namespace configuration is complete."
  value       = try(jsondecode(restapi_object.namespace.api_response).config_status, "UNKNOWN")
}
