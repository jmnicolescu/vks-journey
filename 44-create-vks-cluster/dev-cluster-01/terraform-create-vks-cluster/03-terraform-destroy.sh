#!/usr/bin/env bash
#-------------+----------------------------------------------------------------+
# Script Name | 03-terraform-destroy.sh                                        |
# Updated     | 2026-11-15                                                     |
# Version     | 1.7                                                            |
# VCF Version | 9.1.1                                                          |
# Description | Destroy resources and wait for Cluster deletion.               |
#-------------+----------------------------------------------------------------+

#-------------+----------------------------------------------------------------+
# Requirement | Details                                                        |
#-------------+----------------------------------------------------------------+
# Runtime     | Bash on macOS or Linux; Terraform >= 1.5.0.                    |
# Tools       | Terraform, tee, date, mkdir and dirname available in PATH.     |
# Provider    | hashicorp/kubernetes ~> 3.0; initialize before use.            |
# Inputs      | Terraform files and terraform.tfvars beside this script.       |
# Access      | Authenticated kubeconfig and Supervisor Kubernetes API access. |
# Permissions | Provider permissions for the requested Terraform operation.    |
# Local files | Write access to Terraform state and output-YYYY-MM-DD/.        |
# Output      | output-YYYY-MM-DD/03-terraform-destroy.txt beside this script. |
# Effect      | Destroys managed resources automatically without confirmation. |
# Wait        | Provider waits for Cluster deletion using its saved timeout.   |
# Progress    | Terraform displays Still destroying messages while waiting.    |
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

# Start the transcript and explain the provider's deletion wait.
echo "Destroying managed resources; Terraform waits for Cluster deletion and reports progress." | tee "${OUTPUT_DIR}/03-terraform-destroy.txt"

# Destroy resources and preserve failures while displaying and saving progress.
terraform destroy -no-color -input=false -auto-approve "$@" 2>&1 | tee -a "${OUTPUT_DIR}/03-terraform-destroy.txt"

# Report successful completion only after Terraform finishes without errors.
echo "Terraform destroy completed; all resources selected for destruction have been removed." | tee -a "${OUTPUT_DIR}/03-terraform-destroy.txt"
