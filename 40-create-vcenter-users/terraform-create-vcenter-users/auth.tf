#---------------+------------------------------------------------------------------------------------+
# Script Name   | auth.tf                                                                            |
# Updated       | 2026-11-12                                                                         |
# Version       | 1.1                                                                                |
# VCF Version   | 9.1.1                                                                              |
# Description   | Open and close the REST session used for vCenter permission management.            |
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
# Session       | Creates and closes the REST session for permission management.                     |
#---------------+------------------------------------------------------------------------------------+

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
