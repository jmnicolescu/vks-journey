#-------------+-----------------------------------------------------------------------------------+
# Script Name | main.tf                                                                           |
# Updated     | 2026-11-15                                                                        |
# Version     | 1.5                                                                               |
# VCF Version | 9.1.1.0-545627-2026-09                                                            |
# Description | Create the QA namespace with the same settings as the sibling creation script.   |
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

# Open a temporary vCenter API session and close it after use.
ephemeral "restful_resource" "vcenter_session" {
  path                 = "/api/session"
  method               = "POST"
  use_sensitive_output = true
  open_header = {
    Authorization = "Basic ${base64encode("${var.vcenter_user}:${var.vcenter_password}")}"
  }
  close_path   = "/api/session"
  close_method = "DELETE"
  close_header = {
    "vmware-api-session-id" = "$(body)"
  }
}

# The namespace REST API needs the existing compute cluster ID, not just its display name.
# These read-only lookups find the datacenter_name and cluster_name specified in terraform.tfvars.
# The datacenter scopes the cluster lookup so the configuration does not hardcode a cluster ID.
# They do not create or modify a datacenter, cluster or Supervisor.
# The locals block below uses the resolved cluster ID in the namespace creation payload.
# Find the existing datacenter by its configured name.
data "vsphere_datacenter" "target" {
  name = var.datacenter_name
}

# Find the existing compute cluster within the selected datacenter.
data "vsphere_compute_cluster" "target" {
  name          = var.cluster_name
  datacenter_id = data.vsphere_datacenter.target.id
}

# Resolve each configured storage policy name to its existing identifier.
data "vsphere_storage_policy" "namespace" {
  for_each = toset(var.storage_policy_names)
  name     = each.value
}

# Build the namespace settings from terraform.tfvars for both creation and later updates.
# access_list assigns the users or groups listed in namespace_access as part of the namespace payload.
# With the current settings, it grants the vsphere.local LabUsers group VIEW access to qa-namespace.
# storage_specs includes each resolved storage policy ID and its storage_limit_mib quota.
# resource_spec sets namespace-wide CPU, memory and storage request limits.
# The storage limit applies both to the namespace and to each assigned storage policy.
# vm_service_spec assigns the configured VM classes and omits content-library settings, like the script.
# create_spec adds the namespace name and cluster ID, which are needed only when creating the namespace.
locals {
  settings = {
    description = var.description
    access_list = var.namespace_access
    resource_spec = {
      cpu_limit             = var.cpu_limit_mhz
      memory_limit          = var.memory_limit_mib
      storage_request_limit = var.storage_limit_mib
    }
    storage_specs = [for name in sort(var.storage_policy_names) : {
      policy = data.vsphere_storage_policy.namespace[name].id
      limit  = var.storage_limit_mib
    }]
    vm_service_spec = {
      vm_classes = var.vm_classes
    }
  }
  create_spec = merge(local.settings, {
    cluster   = data.vsphere_compute_cluster.target.id
    namespace = var.namespace_name
  })
}

# This resource manages the namespace, access permissions, storage quotas and VM classes together.
# POST creates the namespace using create_spec; PATCH sends settings when Terraform updates it.
# Unlike the native-provider configuration, permissions and quotas need no separate REST resources.
# GET reads the namespace through the same API, and DELETE removes it when Terraform destroys it.
# Changing the namespace name or compute cluster replaces the namespace instead of updating it.
# Manage namespace creation, settings updates and deletion through the vCenter API.
resource "restapi_object" "namespace" {
  path           = "/api/vcenter/namespaces/instances"
  object_id      = var.namespace_name
  id_attribute   = "namespace"
  create_method  = "POST"
  read_method    = "GET"
  update_method  = "PATCH"
  destroy_method = "DELETE"
  data           = jsonencode(local.create_spec)
  update_data    = jsonencode(local.settings)
  force_new      = ["namespace", "cluster"]
}
