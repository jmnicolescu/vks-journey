#!/usr/bin/env bash
#-------------+----------------------------------------------------------------------+
# Script Name | 02-terraform-apply.sh                                                |
# Updated     | 2026-11-14                                                           |
# Version     | 1.6                                                                  |
# VCF Version | 9.1.1                                                                |
# Description | Run Terraform apply and capture its terminal output.                 |
#-------------+----------------------------------------------------------------------+

#-------------+----------------------------------------------------------------------+
# Requirement | Details                                                              |
#-------------+----------------------------------------------------------------------+
# Runtime     | macOS/Linux Bash; Terraform, tee and standard utilities.             |
# Inputs      | Initialized Terraform configuration beside this script.              |
# Access      | Provider credentials and permissions required by that configuration. |
# Local files | Write permission for output-YYYY-MM-DD/ beside this script.          |
# Effect      | Terraform apply runs without prompting for approval.                 |
#-------------+----------------------------------------------------------------------+

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

# Run Terraform and display and capture its output.
terraform apply -no-color -input=false -auto-approve "$@" 2>&1 | tee "${OUTPUT_DIR}/02-terraform-apply.txt"
