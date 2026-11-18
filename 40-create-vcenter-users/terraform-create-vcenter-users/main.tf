#---------------+------------------------------------------------------------------------------------+
# Script Name   | main.tf                                                                            |
# Updated       | 2026-11-12                                                                         |
# Version       | 1.3                                                                                |
# VCF Version   | 9.1.1                                                                              |
# Description   | Manage SSO users and memberships with vSphere and permissions through REST.        |
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
# Ownership     | Import existing lab users, groups and permissions before applying.                 |
# Membership    | Lab group membership is authoritative; shared groups retain members.               |
#---------------+------------------------------------------------------------------------------------+

# Native SSO resources require vmware/vsphere 2.17.0 or later.
# Import existing accounts/groups before applying; Terraform does not adopt by name.
# Example: terraform import vsphere_sso_user.lab_user labuser@vsphere.local
# Example: terraform import vsphere_sso_user.lab_admin labadministrator@vsphere.local
# Example: terraform import vsphere_sso_group.lab_users LabUsers@vsphere.local
# Example: terraform import vsphere_sso_group.lab_administrators LabAdministrators@vsphere.local
# Group membership is authoritative: review any member removals in the plan.


locals {
  lab_user_password  = var.vcenter_password
  lab_admin_password = var.vcenter_password
}

resource "vsphere_sso_user" "lab_user" {
  name     = var.lab_user
  domain   = var.sso_domain
  password = local.lab_user_password

  lifecycle {
    ignore_changes = [password]
  }
}

resource "vsphere_sso_user" "lab_admin" {
  name     = var.lab_admin
  domain   = var.sso_domain
  password = local.lab_admin_password

  lifecycle {
    ignore_changes = [password]
  }
}

resource "vsphere_sso_group" "lab_users" {
  name = var.lab_user_group

  member_user {
    name   = vsphere_sso_user.lab_user.name
    domain = vsphere_sso_user.lab_user.domain
  }
}

resource "vsphere_sso_group" "lab_administrators" {
  name = var.lab_admin_group

  member_user {
    name   = vsphere_sso_user.lab_admin.name
    domain = vsphere_sso_user.lab_admin.domain
  }
}

# Read the existing shared groups before adding the lab administrator.
# Retain every discovered user, nested group and description.
# Avoid concurrent membership edits between plan and apply.
locals {
  shared_groups = {
    administrators = var.sso_admin_group
    providers      = var.sso_provider_group
  }
}

data "vsphere_sso_group" "shared" {
  for_each = local.shared_groups
  name     = each.value
  domain   = var.sso_domain
}

# Adopt existing shared groups; never attempt to create replacement built-in groups.
import {
  for_each = local.shared_groups
  to       = vsphere_sso_group.shared[each.key]
  id       = "${each.value}@${var.sso_domain}"
}

resource "vsphere_sso_group" "shared" {
  for_each    = local.shared_groups
  name        = each.value
  description = data.vsphere_sso_group.shared[each.key].description

  dynamic "member_user" {
    for_each = setunion(
      toset(data.vsphere_sso_group.shared[each.key].member_user),
      toset([{
        name   = vsphere_sso_user.lab_admin.name
        domain = vsphere_sso_user.lab_admin.domain
      }])
    )
    content {
      name   = member_user.value.name
      domain = member_user.value.domain
    }
  }

  dynamic "member_group" {
    for_each = data.vsphere_sso_group.shared[each.key].member_group
    content {
      name   = member_group.value.name
      domain = member_group.value.domain
    }
  }

  # This blocks terraform destroy while the built-in groups remain in state.
  # These additive memberships must be revoked explicitly when changing users.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [restful_resource.root_permission]
}

data "vsphere_folder" "supervisor" {
  path = var.supervisor_folder
}

data "vsphere_folder" "root" {
  path = "/"
}

# The provider resolves display labels, not internal role names.
data "vsphere_role" "supervisor" {
  label = var.supervisor_role
}

data "vsphere_role" "administrator" {
  label = var.lab_admin_role
}

# Each REST resource owns one permission, leaving unrelated permissions untouched.
# Existing permissions must be imported before applying to avoid AlreadyExists.
# Import ID format (substitute the existing permission ID in the id path):
# terraform import restful_resource.supervisor_permission '{"id":"/api/vcenter/authorization/permissions/PERMISSION_ID","path":"/api/vcenter/authorization/permissions","body":{"object":null,"principal":null,"role":null,"propagating":null}}'
# Use the same format for restful_resource.root_permission and its permission ID.
# Discover IDs through POST /api/vcenter/authorization/permissions?action=list.
# API schema: VCF 9.1.1 Vcenter.Authorization.Permissions.CreateSpec/UpdateSpec.
resource "restful_resource" "supervisor_permission" {
  path            = "/api/vcenter/authorization/permissions"
  read_path       = "$(path)/$(body)"
  create_method   = "POST"
  update_method   = "PATCH"
  delete_method   = "DELETE"
  force_new_attrs = ["object", "principal"]

  body = {
    object = {
      type = "Folder"
      id   = data.vsphere_folder.supervisor.id
    }
    principal = {
      type   = "GROUP"
      name   = vsphere_sso_group.lab_administrators.name
      domain = vsphere_sso_group.lab_administrators.domain
    }
    role        = data.vsphere_role.supervisor.id
    propagating = true
  }

  # PATCH uses is_propagating; POST and GET use propagating.
  merge_patch_disabled = true
  update_body_patches = [{
    path = ""
    raw_json = jsonencode({
      role           = data.vsphere_role.supervisor.id
      is_propagating = true
    })
  }]
}

resource "restful_resource" "root_permission" {
  path            = "/api/vcenter/authorization/permissions"
  read_path       = "$(path)/$(body)"
  create_method   = "POST"
  update_method   = "PATCH"
  delete_method   = "DELETE"
  force_new_attrs = ["object", "principal"]

  body = {
    object = {
      type = "Folder"
      id   = data.vsphere_folder.root.id
    }
    principal = {
      type   = "GROUP"
      name   = vsphere_sso_group.lab_administrators.name
      domain = vsphere_sso_group.lab_administrators.domain
    }
    role        = data.vsphere_role.administrator.id
    propagating = true
  }

  merge_patch_disabled = true
  update_body_patches = [{
    path = ""
    raw_json = jsonencode({
      role           = data.vsphere_role.administrator.id
      is_propagating = true
    })
  }]

  # Create Supervisor access before inherited root Administrator access.
  depends_on = [restful_resource.supervisor_permission]
}
