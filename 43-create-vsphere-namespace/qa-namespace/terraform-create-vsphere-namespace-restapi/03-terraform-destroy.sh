#!/usr/bin/env bash
#-------------+----------------------------------------------------------------+
# Script Name | 03-terraform-destroy.sh                                        |
# Updated     | 2026-11-14                                                     |
# Version     | 1.6                                                            |
# VCF Version | 9.1.1                                                          |
# Description | Run Terraform destroy without prompts and capture its output.  |
#-------------+----------------------------------------------------------------+

#-------------+----------------------------------------------------------------+
# Requirement | Details                                                        |
#-------------+----------------------------------------------------------------+
# Runtime     | Bash on macOS or Linux; Terraform >= 1.5.0.                    |
# Tools       | Terraform, tee, date, mkdir and dirname available in PATH.     |
# Provider    | hashicorp/kubernetes ~> 3.0; initialize before use.            |
# Inputs      | Terraform files and terraform.tfvars beside this script.       |
# Access      | Authenticated kubeconfig and workload Kubernetes API access.   |
# Permissions | Provider permissions for the requested Terraform operation.    |
# Local files | Write access to Terraform state and output-YYYY-MM-DD/.        |
# Output      | output-YYYY-MM-DD/03-terraform-destroy.txt beside this script. |
# Effect      | Destroys managed resources automatically without confirmation. |
#-------------+----------------------------------------------------------------+

# Stop on command and pipeline failures.
set -euo pipefail

# Restrict newly created output files to the current user.
umask 077

# Locate the directory containing this script.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Run Terraform from the directory containing this script.
cd "${SCRIPT_DIR}"

# Capture the local timestamp once for this run.
RUN_TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)

# Save command output in the dated directory beside this script.
OUTPUT_DIR=${SCRIPT_DIR}/output-${RUN_TIMESTAMP:0:10}

# Create the output directory if needed.
mkdir -p "${OUTPUT_DIR}"

# Run Terraform without prompts and display and capture its output.
terraform destroy -no-color -input=false -auto-approve "$@" 2>&1 | tee "${OUTPUT_DIR}/03-terraform-destroy.txt"
