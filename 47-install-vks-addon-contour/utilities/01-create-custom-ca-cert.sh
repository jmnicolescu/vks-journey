#!/bin/bash

#---------------+------------------------------------------------------------+
# Script Name   | 01-create-custom-ca-cert.sh                                |
# Updated       | 2026-11-14                                                 |
# Version       | 1.3                                                        |
# VCF Version   | N/A                                                        |
# Description   | Generate a private CA certificate.                         |
#---------------+------------------------------------------------------------+

#---------------+------------------------------------------------------------+
# Requirement   | Details                                                    |
#---------------+------------------------------------------------------------+
# Runtime       | Bash on macOS or Linux; OpenSSL 3.3 or later.              |
# Tools         | openssl, dirname, mkdir, chmod, cat.                       |
# Configuration | Edit the lab certificate settings below before reuse.      |
# Access        | Local write access; no network or VCF authentication.      |
# Output        | certificates/ beside the scripts.                          |
# Permissions   | Private keys are unencrypted; files use owner-only access. |
# Rerun         | Existing keys and certificates are not overwritten.        |
#---------------+------------------------------------------------------------+

# Stop when a command fails.
set -e

# Restrict newly created files and directories to the current user.
umask 077

# Lab certificate settings; replace these values for another environment.
SERVER_DOMAIN_NAME=platformlab.vcf
CA_PRIVATE_KEY=ca_platformlab_vcf.key
CA_CERTIFICATE=ca_platformlab_vcf.crt
CA_CONFIG_FILE=ca_platformlab_vcf.cnf
CA_KEY_SIZE=4096
CA_VALIDITY_DAYS=3650

# Resolve the script directory, retaining support for paths containing spaces.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Set the shared certificate directory.
CERTIFICATES_DIR=${SCRIPT_DIR}/certificates

# Create the certificate output directory.
mkdir -p "${CERTIFICATES_DIR}"

# Set the certificate and configuration paths.
CA_PRIVATE_KEY_PATH=${CERTIFICATES_DIR}/${CA_PRIVATE_KEY}
CA_CERTIFICATE_PATH=${CERTIFICATES_DIR}/${CA_CERTIFICATE}
CA_CONFIG_PATH=${CERTIFICATES_DIR}/${CA_CONFIG_FILE}

# Prevent accidental replacement of an existing CA.
if [ -e "${CA_PRIVATE_KEY_PATH}" ] || [ -e "${CA_CERTIFICATE_PATH}" ]; then
    echo "ERROR: CA private key or certificate already exists."
    echo "Existing CA files will not be overwritten."
    exit 1
fi

# Write the OpenSSL certificate configuration.
cat <<EOF > "${CA_CONFIG_PATH}"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C  = GB
ST = Greater London
L  = London
O  = PLATFORMLAB
OU = PRIVATE CA
CN = CA.${SERVER_DOMAIN_NAME}

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

# Generate the RSA private key.
openssl genrsa \
    -out "${CA_PRIVATE_KEY_PATH}" \
    ${CA_KEY_SIZE}

# Restrict access to the CA private key.
chmod 600 "${CA_PRIVATE_KEY_PATH}"

# Create the self-signed CA certificate.
openssl req -x509 -new -sha512 \
    -days ${CA_VALIDITY_DAYS} \
    -key "${CA_PRIVATE_KEY_PATH}" \
    -out "${CA_CERTIFICATE_PATH}" \
    -config "${CA_CONFIG_PATH}" \
    -extensions v3_ca

# Display the certificate subject, issuer, and validity period.
openssl x509 \
    -in "${CA_CERTIFICATE_PATH}" \
    -noout \
    -subject \
    -issuer \
    -dates

# Verify the CA certificate signature.
openssl verify \
    -CAfile "${CA_CERTIFICATE_PATH}" \
    "${CA_CERTIFICATE_PATH}"

# Show where the generated certificate files were saved.
echo "Certificate files: ${CERTIFICATES_DIR}"
