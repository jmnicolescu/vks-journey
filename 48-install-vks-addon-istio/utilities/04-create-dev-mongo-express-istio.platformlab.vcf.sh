#!/bin/bash

#---------------+------------------------------------------------------------+
# Script Name   | 04-create-dev-mongo-express-istio.platformlab.vcf.sh       |
# Updated       | 2026-11-14                                                 |
# Version       | 1.3                                                        |
# VCF Version   | N/A                                                        |
# Description   | Generate and verify a CA-signed TLS server certificate.    |
#---------------+------------------------------------------------------------+

#---------------+------------------------------------------------------------+
# Requirement   | Details                                                    |
#---------------+------------------------------------------------------------+
# Runtime       | Bash on macOS or Linux; OpenSSL 3.3 or later.              |
# Tools         | openssl, dirname, mkdir, chmod, cat, cp.                   |
# Configuration | Edit the lab certificate settings below before reuse.      |
# Input         | CA key and certificate from 01-create-custom-ca-cert.sh.   |
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
SERVER_FQDN=dev-mongo-express-istio.platformlab.vcf
SERVER_KEY_SIZE=4096
SERVER_VALIDITY_DAYS=3650

CA_PRIVATE_KEY=ca_platformlab_vcf.key
CA_CERTIFICATE=ca_platformlab_vcf.crt

# Resolve the script directory, retaining support for paths containing spaces.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Set the shared certificate directory.
CERTIFICATES_DIR=${SCRIPT_DIR}/certificates

# Create the certificate output directory.
mkdir -p "${CERTIFICATES_DIR}"

# Set the certificate and configuration paths.
CA_PRIVATE_KEY_PATH=${CERTIFICATES_DIR}/${CA_PRIVATE_KEY}
CA_CERTIFICATE_PATH=${CERTIFICATES_DIR}/${CA_CERTIFICATE}
SERVER_PRIVATE_KEY_PATH=${CERTIFICATES_DIR}/${SERVER_FQDN}.key
SERVER_CSR_PATH=${CERTIFICATES_DIR}/${SERVER_FQDN}.csr
SERVER_CERTIFICATE_PATH=${CERTIFICATES_DIR}/${SERVER_FQDN}.crt
SERVER_CERTIFICATE_CER_PATH=${CERTIFICATES_DIR}/${SERVER_FQDN}.cer
SERVER_CERTIFICATE_CHAIN_PATH=${CERTIFICATES_DIR}/${SERVER_FQDN}.cer.plusCA
SERVER_CONFIG_PATH=${CERTIFICATES_DIR}/${SERVER_FQDN}.cnf

# Verify that the CA private key exists.
if [ ! -r "${CA_PRIVATE_KEY_PATH}" ]; then
    echo "ERROR: CA private key not found or not readable."
    echo "Expected: ${CA_PRIVATE_KEY_PATH}"
    exit 1
fi

# Verify that the CA certificate exists.
if [ ! -r "${CA_CERTIFICATE_PATH}" ]; then
    echo "ERROR: CA certificate not found or not readable."
    echo "Expected: ${CA_CERTIFICATE_PATH}"
    exit 1
fi

# Prevent accidental replacement of an existing server certificate.
for FILE in \
    "${SERVER_PRIVATE_KEY_PATH}" \
    "${SERVER_CSR_PATH}" \
    "${SERVER_CERTIFICATE_PATH}" \
    "${SERVER_CERTIFICATE_CER_PATH}" \
    "${SERVER_CERTIFICATE_CHAIN_PATH}"; do

    if [ -e "${FILE}" ]; then
        echo "ERROR: Server certificate file already exists."
        echo "Existing file: ${FILE}"
        echo "Existing certificate files will not be overwritten."
        exit 1
    fi
done

# Write the OpenSSL certificate configuration.
cat <<EOF > "${SERVER_CONFIG_PATH}"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C  = GB
ST = Greater London
L  = London
O  = PLATFORMLAB
OU = Digital Technology
CN = ${SERVER_FQDN}

[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[v3_server]
authorityKeyIdentifier = keyid,issuer
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SERVER_FQDN}
EOF

# Generate the RSA private key.
openssl genrsa \
    -out "${SERVER_PRIVATE_KEY_PATH}" \
    ${SERVER_KEY_SIZE}

# Restrict access to the server private key.
chmod 600 "${SERVER_PRIVATE_KEY_PATH}"

# Create the server certificate signing request.
openssl req -new -sha512 \
    -key "${SERVER_PRIVATE_KEY_PATH}" \
    -out "${SERVER_CSR_PATH}" \
    -config "${SERVER_CONFIG_PATH}" \
    -reqexts v3_req

# Verify the CSR signature.
openssl req \
    -in "${SERVER_CSR_PATH}" \
    -noout \
    -verify

# Display the CSR subject and requested extensions.
openssl req \
    -in "${SERVER_CSR_PATH}" \
    -noout \
    -subject \
    -text

# Sign the server certificate with the selected CA.
openssl x509 -req -sha512 \
    -days ${SERVER_VALIDITY_DAYS} \
    -in "${SERVER_CSR_PATH}" \
    -CA "${CA_CERTIFICATE_PATH}" \
    -CAkey "${CA_PRIVATE_KEY_PATH}" \
    -CAserial "${CERTIFICATES_DIR}/ca.srl" -CAcreateserial \
    -out "${SERVER_CERTIFICATE_PATH}" \
    -extfile "${SERVER_CONFIG_PATH}" \
    -extensions v3_server

# Save a PEM copy with the .cer extension.
cp \
    "${SERVER_CERTIFICATE_PATH}" \
    "${SERVER_CERTIFICATE_CER_PATH}"

# Combine the server certificate with its issuing CA certificate.
cat \
    "${SERVER_CERTIFICATE_CER_PATH}" \
    "${CA_CERTIFICATE_PATH}" \
    > "${SERVER_CERTIFICATE_CHAIN_PATH}"

# Display certificate subject, issuer, and validity period.
openssl x509 \
    -in "${SERVER_CERTIFICATE_PATH}" \
    -noout \
    -subject \
    -issuer \
    -dates

# Display the issued certificate extensions.
openssl x509 \
    -in "${SERVER_CERTIFICATE_PATH}" \
    -noout \
    -text

# Verify the certificate chain, intended usage, and hostname.
openssl verify \
    -verbose \
    -purpose sslserver \
    -verify_hostname ${SERVER_FQDN} \
    -CAfile "${CA_CERTIFICATE_PATH}" \
    "${SERVER_CERTIFICATE_PATH}"

# Show where the generated certificate files were saved.
echo "Certificate files: ${CERTIFICATES_DIR}"
