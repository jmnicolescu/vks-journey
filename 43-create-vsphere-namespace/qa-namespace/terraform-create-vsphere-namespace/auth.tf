#-------------+----------------------------------------------------------------------------------+
# Script Name | auth.tf                                                                          |
# Updated     | 2026-11-15                                                                       |
# Version     | 1.2                                                                              |
# VCF Version | 9.1.1.0-545627-2026-09                                                           |
# Description | Open and close a temporary vCenter API session.                                  |
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

# Open a temporary vCenter API session and close it after use.
ephemeral "restful_resource" "vcenter_session" {
  provider             = restful.session
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
