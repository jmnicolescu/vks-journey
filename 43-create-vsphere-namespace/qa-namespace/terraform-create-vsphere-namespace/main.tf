#-------------+----------------------------------------------------------------------------------+
# Script Name | main.tf                                                                          |
# Updated     | 2026-11-15                                                                       |
# Version     | 1.7                                                                              |
# VCF Version | 9.1.1.0-545627-2026-09                                                           |
# Description | Create the QA namespace and its direct access permissions.                      |
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

# The namespace resource needs the existing Supervisor ID, not just its display name.
# This read-only GET request retrieves the Supervisor inventory from vCenter so the configuration
# can find the supervisor_name specified in terraform.tfvars without hardcoding its ID.
# The checks stop Terraform if the name matches zero or multiple Supervisors, or if the matching
# ID does not have the expected UUID format. They do not create or modify a Supervisor.
# The locals block below extracts the matching ID for use when creating the namespace.
data "restful_resource" "supervisors" {
  id     = "/api/vcenter/namespace-management/supervisors/summaries"
  method = "GET"

  lifecycle {
    postcondition {
      condition = try(length([
        for item in self.output.items : item
        if item.info.name == var.supervisor_name
      ]) == 1, false)
      error_message = "Supervisor discovery must return exactly one match for the configured supervisor_name."
    }
    postcondition {
      condition = try(can(regex(
        "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
        one([for item in self.output.items : item.supervisor if item.info.name == var.supervisor_name])
      )), false)
      error_message = "Supervisor discovery did not return a valid UUID for the configured name."
    }
  }
}

locals {
  supervisor_id = try(one([
    for item in data.restful_resource.supervisors.output.items : item.supervisor
    if item.info.name == var.supervisor_name
  ]), "")
}

# Resolve each configured storage policy name to its existing identifier.
data "vsphere_storage_policy" "namespace" {
  for_each = toset(var.storage_policy_names)
  name     = each.value
}

# Resolve each configured content library name to its existing identifier.
data "vsphere_content_library" "namespace" {
  for_each = toset(var.content_library_names)
  name     = each.value
}

# Manage the namespace and its storage, VM class and content library associations.
resource "vsphere_namespace" "namespace" {
  name             = var.namespace_name
  supervisor       = local.supervisor_id
  storage_policies = [for name in sort(var.storage_policy_names) : data.vsphere_storage_policy.namespace[name].id]

  vm_service {
    content_libraries = [for name in sort(var.content_library_names) : data.vsphere_content_library.namespace[name].id]
    vm_classes        = sort(var.vm_classes)
  }
}

# The namespace resource above creates the namespace and configures storage and VM settings.
# This separate block assigns the user or group roles listed in namespace_access in terraform.tfvars.
# With the current settings, it grants the vsphere.local LabUsers group VIEW access to qa-namespace.
# Without this block, this configuration would create the namespace without assigning that permission.
# Each permission is managed separately so Terraform can add, update or remove it as the inputs change.
resource "restful_resource" "namespace_access" {
  for_each = {
    for access in var.namespace_access :
    jsonencode([access.domain, access.subject, access.subject_type]) => access
  }

  path = "/api/vcenter/namespaces/instances/${vsphere_namespace.namespace.name}/access/${urlencode(each.value.domain)}/${urlencode(each.value.subject)}"
  query = {
    type = [each.value.subject_type]
  }
  create_method = "POST"
  update_method = "PUT"
  delete_method = "DELETE"
  body = {
    role = each.value.role
  }
}

# The VMware namespace resource has no CPU, memory or storage quota fields.
# After namespace creation, set namespace quotas and each assigned storage policy limit.
# Reapply this operation when its inputs or the namespace resource change. This operation
# does not detect quota changes made outside Terraform. Removing it does not reset quotas;
# namespace deletion remains the responsibility of the VMware namespace resource.
# Configure namespace CPU, memory and storage quotas plus per-policy storage limits.
resource "restful_operation" "namespace_storage_quota" {
  path   = "/api/vcenter/namespaces/instances/${vsphere_namespace.namespace.name}"
  method = "PATCH"
  body = {
    resource_spec = {
      cpu_limit             = var.cpu_limit_mhz
      memory_limit          = var.memory_limit_mib
      storage_request_limit = var.storage_limit_mib
    }
    storage_specs = [for name in sort(var.storage_policy_names) : {
      policy = data.vsphere_storage_policy.namespace[name].id
      limit  = var.storage_limit_mib
    }]
  }

  lifecycle {
    replace_triggered_by = [vsphere_namespace.namespace]
  }
}
