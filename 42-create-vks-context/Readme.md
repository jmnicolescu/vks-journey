<!--
authors: "Julius M. Nicolescu, Qwen3-Coder-30B-A3B-Instruct-4bit, Qwen3.8-27B-8bit"
date: 2026-11-18
description: Create, select, verify and manage Supervisor and VKS contexts with VCF CLI, manually or with Bash, PowerShell and batch examples.
keywords: VCF 9.1.1, Supervisor, VKS, VCF CLI, context, kubeconfig, vCenter SSO
lang: en
-->

# Create Supervisor and VKS cluster contexts

Create local **Supervisor** and **VKS workload cluster** connections with VCF CLI in VMware Cloud Foundation **9.1.1**. Use the manual procedures or the supplied Bash, PowerShell 7 and Command Prompt examples, then select the intended Kubernetes context and verify API access.

**Documentation scope:** DEV is the worked example. QA follows the same procedure with its own namespace, cluster and context names. The target and script tables cover both environments.

| Target | Supervisor namespace | Local VCF connection | Kubernetes context |
| --- | --- | --- | --- |
| Supervisor | Not required | `supervisor` | `supervisor` |
| DEV VKS cluster | `dev-namespace` | `dev-cluster-01` | `dev-cluster-01:dev-cluster-01` |
| QA VKS cluster | `qa-namespace` | `qa-cluster-02` | `qa-cluster-02:qa-cluster-02` |

Context creation uses the **Supervisor control-plane endpoint** for every target. Workload flags identify the existing cluster inside its Supervisor namespace. The combined workload context name uses the local connection name followed by the cluster name; these examples use the same name for both.

## Contents

- [Reference environment](#reference-environment)
- [Automated alternatives](#automated-alternatives)
- [Prerequisites](#prerequisites)
- [Prepare the DEV configuration](#prepare-the-dev-configuration)
- [Create contexts on macOS/Linux](#create-contexts-on-macoslinux)
- [Create contexts on Windows](#create-contexts-on-windows)
- [Verify access](#verify-access)
- [Manage existing contexts](#manage-existing-contexts)
- [Project files](#project-files)
- [Optional cleanup](#optional-cleanup)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Reference environment

| Component | Version or scope |
| --- | --- |
| Target platform | VMware Cloud Foundation `9.1.1`. |
| Script VCF version | `9.1.1.0-545627-2026-09`, recorded in the context-script headers. |
| Workstation VCF CLI | `v9.1.1.0100.25746586`, build date `2026-09-11`, macOS `arm64`; checked on 2026-11-18. |
| Documentation | Broadcom VCF Consumption `latest`; its navigation identifies VCF Consumption CLI v9.1.1. |

The version and local CLI help checks establish the command reference used for this guide. Authentication, cluster availability and node readiness require the [access checks](#verify-access) against your environment.

## Automated alternatives

The nine context scripts are examples with independent settings. Choose one runtime for each target. Each context script deletes its named local VCF connection with `-y`, recreates it, selects the Kubernetes context and requests nodes. Run the commands below from the directory containing this README.

### Supervisor

| Script | What it does | Run from this directory |
| --- | --- | --- |
| [01-create-supervisor-context.sh](01-create-supervisor-context.sh) | Retrieve the certificate and recreate the Supervisor context with Bash. | `bash ./01-create-supervisor-context.sh` |
| [11-create-supervisor-context.ps1](11-create-supervisor-context.ps1) | Retrieve the certificate and recreate the Supervisor context with PowerShell 7. | `pwsh -File ./11-create-supervisor-context.ps1` |
| [21-create-supervisor-context.bat](21-create-supervisor-context.bat) | Recreate the Supervisor context with certificate verification disabled. | `21-create-supervisor-context.bat` |

### DEV VKS cluster

| Script | What it does | Run from this directory |
| --- | --- | --- |
| [01-create-vks-cluster-context.sh](dev-cluster-01/01-create-vks-cluster-context.sh) | Retrieve the certificate and recreate the DEV context with Bash. | `bash ./dev-cluster-01/01-create-vks-cluster-context.sh` |
| [11-create-vks-cluster-context.ps1](dev-cluster-01/11-create-vks-cluster-context.ps1) | Retrieve the certificate and recreate the DEV context with PowerShell 7. | `pwsh -File ./dev-cluster-01/11-create-vks-cluster-context.ps1` |
| [21-create-vks-cluster-context.bat](dev-cluster-01/21-create-vks-cluster-context.bat) | Recreate the DEV context with certificate verification disabled. | `dev-cluster-01\21-create-vks-cluster-context.bat` |

### QA VKS cluster

| Script | What it does | Run from this directory |
| --- | --- | --- |
| [01-create-vks-cluster-context.sh](qa-cluster-02/01-create-vks-cluster-context.sh) | Retrieve the certificate and recreate the QA context with Bash. | `bash ./qa-cluster-02/01-create-vks-cluster-context.sh` |
| [11-create-vks-cluster-context.ps1](qa-cluster-02/11-create-vks-cluster-context.ps1) | Retrieve the certificate and recreate the QA context with PowerShell 7. | `pwsh -File ./qa-cluster-02/11-create-vks-cluster-context.ps1` |
| [21-create-vks-cluster-context.bat](qa-cluster-02/21-create-vks-cluster-context.bat) | Recreate the QA context with certificate verification disabled. | `qa-cluster-02\21-create-vks-cluster-context.bat` |

Bash and PowerShell examples retrieve the Supervisor certificate themselves. All three batch examples use `--insecure-skip-tls-verify` and do not read a certificate file. Use the manual certificate-based procedure when you need an administrator-provided CA bundle.

**Optional DEV-to-QA file preparation:**

| Script | What it does | Run from this directory |
| --- | --- | --- |
| [00-copy-dev-cluster-01-to-qa-cluster-02.sh](00-copy-dev-cluster-01-to-qa-cluster-02.sh) | Delete and rebuild the local `qa-cluster-02` folder from DEV files, then replace known DEV names with QA names. | `bash ./00-copy-dev-cluster-01-to-qa-cluster-02.sh` |

This helper is separate from context creation. The QA scripts are already supplied, so running it is optional. It removes existing QA files, including local edits and backups, before copying; it does not back them up. Review [Project files](#project-files) before using it.

## Prerequisites

| Requirement | Details |
| --- | --- |
| Target platform | VMware Cloud Foundation 9.1.1 with an enabled, reachable Supervisor. |
| Existing resources | The selected VKS cluster and its Supervisor namespace must exist. A Supervisor context can be created before workload clusters exist. |
| Workstation tools | VCF CLI and kubectl in `PATH`. See the [CLI installation guide](../41-install-vcf-cli-kubectl/Readme.md) for tools and plugins. |
| Runtime | Bash on macOS/Linux, PowerShell 7.0 or later, or Windows Command Prompt for `.bat` examples. |
| OpenSSL | Required by the three Bash context scripts and the manual Bash certificate-extraction command. Manual commands with a prepared PEM, native PowerShell extraction and batch examples do not require it. |
| Connectivity | Reach the Supervisor API on TCP 443 and the selected workload API at the address and port recorded in kubeconfig. |
| Identity and access | vCenter SSO credentials and access to the intended namespace and cluster. Listing nodes requires cluster-level Kubernetes permission. |
| Certificate trust | For the secure manual procedure, obtain a verified PEM certificate or full CA chain covering the Supervisor endpoint. See [secure login guidance][secure-login]. |
| Local permissions | Write access to VCF CLI configuration and kubeconfig. Bash and PowerShell scripts also write a temporary certificate file. Manual commands need read access to the supplied certificate. |
| Optional copy helper | Bash, `rsync`, `rm`, `mkdir`, `dirname`, `find` and Perl. Keep `dev-cluster-01` beside the helper; allow reading DEV and replacing the local QA folder. Its unquoted paths require a project path without spaces. These are helper-only requirements. |

## Prepare the DEV configuration

Start in the directory containing this README. Choose either the manual procedure or one example script for each target. Supervisor and workload connections can be created independently; a separate local Supervisor context is not required before creating a workload connection.

### Collect the required values

Obtain these values before opening a terminal. The [official Supervisor login procedure][supervisor-login] lists the endpoint, identity and namespace-access prerequisites. The [official VKS login procedure][vks-login] adds the workload cluster and its Supervisor namespace.

| Input | Required value | Where to obtain it |
| --- | --- | --- |
| Supervisor endpoint | The Supervisor control-plane IP or configured FQDN, without `https://` or a path. | Supervisor administrator. This is the endpoint used to create both Supervisor and VKS connections. |
| SSO identity | Your vCenter Single Sign-On username, including its domain, and password. | The administrator who granted your namespace and cluster access. |
| Supervisor namespace | The namespace containing the existing VKS cluster. DEV example: `dev-namespace`. | Cluster owner or Supervisor administrator. |
| VKS cluster name | The existing workload cluster name. DEV example: `dev-cluster-01`. | Cluster owner or Supervisor inventory. |
| Certificate or CA bundle | A verified PEM file appropriate for the Supervisor endpoint. | Platform or certificate administrator; see [Prepare the certificate file](#prepare-the-certificate-file). |
| Workload API address | The expected VKS control-plane endpoint, used to check the connection after login. | Cluster owner or administrator; compare it with the server recorded in kubeconfig. |

### Manual terminal settings

Use **one terminal session** for preparation, creation, selection and verification. Start in the directory containing this README, with write access to VCF CLI configuration and kubeconfig. The examples use the default kubeconfig unless you have deliberately set `KUBECONFIG`.

1. Open Bash on macOS/Linux or PowerShell 7 on Windows.
2. Run the assignment block for that shell below. Replace `supervisor.example.com` and `operator@example.com` with your actual endpoint and username. Set the existing workload namespace and cluster names.
3. Prepare `./supervisor-ca.pem` using the certificate section below.
4. Continue with the procedure for your operating system. Run only the targets you need and complete each command successfully before the next one.

**Bash:**

```bash
SUPERVISOR_API_ENDPOINT=supervisor.example.com
VCF_CLI_VSPHERE_USERNAME=operator@example.com
CERTIFICATE_FILE=./supervisor-ca.pem

CLUSTER_NAMESPACE=dev-namespace
CLUSTER_NAME=dev-cluster-01
```

**PowerShell 7:**

```powershell
$SUPERVISOR_API_ENDPOINT = 'supervisor.example.com'
$VCF_CLI_VSPHERE_USERNAME = 'operator@example.com'
$CERTIFICATE_FILE = './supervisor-ca.pem'

$CLUSTER_NAMESPACE = 'dev-namespace'
$CLUSTER_NAME = 'dev-cluster-01'
```

Assignments configure the current shell; they do not log in. Use a certificate path without spaces for these unquoted Bash examples. For QA, change `CLUSTER_NAMESPACE` to `qa-namespace` and `CLUSTER_NAME` to `qa-cluster-02` before creating its workload connection. Keep `CLUSTER_NAME` as the cluster name here, without the combined context suffix.

The manual commands prompt for the SSO password when required. If your terminal already has `VCF_CLI_VSPHERE_PASSWORD` set, VCF CLI can use it instead. The supplied scripts have their own assignments; terminal settings do not override them.

### Prepare the certificate file

The main procedure uses `--ca-certificate` and requires a readable PEM file before context creation. Follow [Configure Secure Login for vSphere Supervisor][secure-login], particularly **Supervisor CA Certificate**.

1. Ask your administrator which CA signs the Supervisor endpoint certificate and obtain the matching PEM trust chain. Confirm its identity through your administrator.
2. If the endpoint uses the vCenter CA, follow [KB 330833 — Certificate Download in Small Deployments][root-ca]. Open the vCenter base URL in a browser, select **Download trusted root CA certificates**, and extract the downloaded ZIP. The KB distinguishes certificate files from certificate revocation lists.
3. Have the appropriate root and intermediate certificates assembled in PEM format as `./supervisor-ca.pem`, or set `CERTIFICATE_FILE` to the administrator-provided bundle. A downloaded ZIP or CRL file cannot be used as `--ca-certificate` input. For a custom CA, use that CA's chain rather than assuming the vCenter root applies.
4. Keep the file at that path while completing the procedure. See [KB 460364][certificate-kb] for full-chain requirements and the operating-system trust alternative.

The vCenter address in the certificate-download step is distinct from the **Supervisor endpoint** passed to `vcf context create`.

### Choose certificate handling

| Method | Preparation | Creation-command option |
| --- | --- | --- |
| Explicit certificate trust | Obtain a verified PEM certificate or full CA chain and set `CERTIFICATE_FILE`. Use an endpoint covered by its certificate. | `--ca-certificate`. |
| Operating-system trust | Ensure the endpoint's signing CA is already trusted by the workstation. | Omit `--ca-certificate` and keep normal TLS verification; see [KB 460364][certificate-kb]. |
| Skip verification for a lab or troubleshooting | No certificate file is required. HTTPS remains encrypted, but the server identity is not checked. | Replace `--ca-certificate` and its path with `--insecure-skip-tls-verify`. |

Choose one method for each connection. The procedures below use an explicit certificate file. See [secure Supervisor login][secure-login] for trust configuration.

### Extract the Supervisor API certificate

If you already have a verified administrator-provided CA bundle, keep it and skip extraction. Otherwise, the following alternatives retrieve the presented server certificate and overwrite `CERTIFICATE_FILE`. They do not independently establish the endpoint's identity or assemble a complete CA chain.

Set the manual variables above first, then use the extraction method for your platform.

**macOS/Linux — Bash with OpenSSL:**

```bash
# Display the certificate retrieval step.
echo "Retrieving the Supervisor API certificate..."

# Retrieve the Supervisor API certificate and save it as PEM.
openssl s_client -connect ${SUPERVISOR_API_ENDPOINT}:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM > ${CERTIFICATE_FILE}
```

`openssl s_client` retrieves the certificates presented by the endpoint. `openssl x509` extracts a single server certificate and writes it to `${CERTIFICATE_FILE}`; the pipeline does not build a full CA bundle.

**Windows — PowerShell 7 using native .NET TLS APIs:**

This is the equivalent used by the PowerShell scripts. It does not require OpenSSL.

```powershell
# Display the certificate retrieval step.
Write-Host "Retrieving the Supervisor API certificate..."

# Open a TCP connection to the Supervisor API.
$tcp = [Net.Sockets.TcpClient]::new($SUPERVISOR_API_ENDPOINT, 443)

# Create a TLS stream that accepts the presented certificate for extraction.
$tls = [Net.Security.SslStream]::new($tcp.GetStream(), $false, { $true })

# Complete the TLS handshake with the Supervisor endpoint.
$tls.AuthenticateAsClient($SUPERVISOR_API_ENDPOINT)

# Read the server certificate presented during the handshake.
$certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($tls.RemoteCertificate)

# Convert the certificate bytes to wrapped Base64 text.
$base64 = [Convert]::ToBase64String($certificate.RawData, [Base64FormattingOptions]::InsertLineBreaks)

# Write the certificate to the configured file in PEM format.
Set-Content -LiteralPath $CERTIFICATE_FILE -Value "-----BEGIN CERTIFICATE-----`n$base64`n-----END CERTIFICATE-----" -Encoding ascii

# Close the TLS stream.
$tls.Dispose()

# Close the TCP connection.
$tcp.Dispose()

# Release the certificate object.
$certificate.Dispose()
```

Check the certificate against an administrator-provided fingerprint or trusted CA before using it. For a CA-signed endpoint, supply the required intermediate and root certificates; a single extracted server certificate may be insufficient. See [KB 460364][certificate-kb].

The supplied Bash and PowerShell scripts perform their own extraction and replace their shared temporary certificate file on each run. Run those scripts sequentially. Batch scripts skip extraction and disable certificate verification.

### Context-creation arguments

The [official `vcf context create` reference][context-create] defines these arguments. The same options apply in Bash and PowerShell; only variable and line-continuation syntax changes.

| Argument | Meaning in this procedure |
| --- | --- |
| `supervisor` or `CLUSTER_NAME` after `create` | Name of the local VCF connection. It does not create an infrastructure cluster. |
| `--endpoint` | Supervisor control-plane endpoint for both connection types. |
| `--username` | vCenter SSO identity. |
| `--type k8s` | Select the Kubernetes connection type. |
| `--auth-type basic` | Use vCenter SSO authentication explicitly; see [KB 417617][basic-auth]. |
| `--ca-certificate` | Path to the verified PEM certificate or CA bundle. |
| `--workload-cluster-namespace` | Existing Supervisor namespace containing the VKS cluster; used only for the workload connection. |
| `--workload-cluster-name` | Existing VKS cluster to access; used only for the workload connection. |

## Create contexts on macOS/Linux

Run these commands in **Bash on your workstation**. First complete [Manual terminal settings](#manual-terminal-settings) and [Prepare the certificate file](#prepare-the-certificate-file) in the same terminal. Use the main certificate-based commands below, or apply one alternative from [Choose certificate handling](#choose-certificate-handling).

| Target needed | Steps to run |
| --- | --- |
| Supervisor access only | Steps 1–3. |
| DEV VKS access only | Steps 1, 4 and 5. A separate local Supervisor connection is not required. |
| Both | Steps 1–5. Step 5 leaves the workload context selected. |

### 1. Confirm tools, certificate file and existing connections

```bash
# Display the installed VCF CLI version.
vcf version

# Confirm kubectl is available without connecting to a cluster.
kubectl version --client

# Confirm the configured certificate file exists and is readable by your account.
ls -l ${CERTIFICATE_FILE}

# List local VCF connections and related contexts.
vcf context list --wide

# List Kubernetes contexts in kubeconfig.
kubectl config get-contexts
```

Confirm the tools are available and the certificate path points to the PEM file you prepared. If the intended connection already works, skip its creation command and select it below. If its endpoint or identity must change, use [Optional cleanup](#optional-cleanup) for that connection, then return to its creation step.

### 2. Create the Supervisor connection

**Official procedure:** [Connect to the Supervisor as a vCenter Single Sign-On User][supervisor-login].

```bash
# Create the local Supervisor connection with SSO authentication and certificate verification.
vcf context create supervisor \
    --endpoint https://${SUPERVISOR_API_ENDPOINT} \
    --username ${VCF_CLI_VSPHERE_USERNAME} \
    --ca-certificate ${CERTIFICATE_FILE} \
    --type k8s \
    --auth-type basic
```

Enter the SSO password when prompted. Wait for the command to complete successfully. It writes local connection and authentication configuration for the existing Supervisor. If it returns a TLS, authentication or permission error, resolve that error before proceeding.

### 3. Select the Supervisor and verify its API

```bash
# List the VCF contexts created by the login operation.
vcf context list --wide

# Select the Supervisor for subsequent VCF CLI operations.
vcf context use supervisor

# Select the same Supervisor for subsequent Kubernetes commands.
kubectl config use-context supervisor

# Confirm that the active Kubernetes context is supervisor.
kubectl config current-context

# Display the API endpoint associated with the selected context.
kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"

# Request nodes from the Supervisor API.
kubectl get nodes
```

The `supervisor` entry must be present, `current-context` must report `supervisor`, and the server must match the intended Supervisor endpoint. The node query must reach that API and return the expected nodes, subject to your node-read permissions. See [Verify access](#verify-access) for result interpretation.

### 4. Create the DEV workload connection

**Official procedure:** [Log in to a VKS Cluster Using vCenter Single Sign-On Credentials][vks-login]. Confirm that `dev-cluster-01` already exists in `dev-namespace`, or use your actual values from preparation.

```bash
# Create a local connection to the existing DEV cluster through its Supervisor.
vcf context create ${CLUSTER_NAME} \
    --endpoint https://${SUPERVISOR_API_ENDPOINT} \
    --username ${VCF_CLI_VSPHERE_USERNAME} \
    --workload-cluster-namespace ${CLUSTER_NAMESPACE} \
    --workload-cluster-name ${CLUSTER_NAME} \
    --ca-certificate ${CERTIFICATE_FILE} \
    --type k8s \
    --auth-type basic
```

Enter the SSO password when prompted and wait for successful completion. The endpoint is still the Supervisor; the workload flags identify the VKS cluster to access. This command configures local access to that cluster.

### 5. Select the DEV workload context and verify its API

```bash
# List VCF connections and the exact workload context names.
vcf context list --wide

# Select the workload context for VCF CLI operations.
vcf context use ${CLUSTER_NAME}:${CLUSTER_NAME}

# Select the workload context for Kubernetes commands.
kubectl config use-context ${CLUSTER_NAME}:${CLUSTER_NAME}

# Confirm the selected workload Kubernetes context.
kubectl config current-context

# Display the workload API endpoint recorded in kubeconfig.
kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"

# Request nodes from the selected VKS workload cluster.
kubectl get nodes
```

For the DEV values above, the expected context is `dev-cluster-01:dev-cluster-01`. Use the exact name returned by the context listing if your naming differs. Compare the selected server with the DEV cluster API address supplied by your administrator. The node list must contain DEV workload nodes.

For QA, change the two workload assignments in [Manual terminal settings](#manual-terminal-settings), then repeat steps 4 and 5. The expected context becomes `qa-cluster-02:qa-cluster-02` and the selected server and nodes must belong to QA.

**Automated alternative:** after reviewing its editable settings and replacement behavior, run the Bash example listed in [Automated alternatives](#automated-alternatives).

## Create contexts on Windows

Run these commands in **PowerShell 7 on your workstation**. First execute the PowerShell assignments in [Manual terminal settings](#manual-terminal-settings), then complete [Prepare the certificate file](#prepare-the-certificate-file). Keep this session open for all steps.

| Target needed | Steps to run |
| --- | --- |
| Supervisor access only | Steps 1–3. |
| DEV VKS access only | Steps 1, 4 and 5. A separate local Supervisor connection is not required. |
| Both | Steps 1–5. Step 5 leaves the workload context selected. |

### 1. Confirm tools, certificate file and existing connections

```powershell
# Display the installed VCF CLI version.
vcf version

# Confirm kubectl is available without connecting to a cluster.
kubectl version --client

# Confirm the configured certificate file exists and inspect its location.
Get-Item -LiteralPath $CERTIFICATE_FILE

# List local VCF connections and related contexts.
vcf context list --wide

# List Kubernetes contexts in kubeconfig.
kubectl config get-contexts
```

Confirm both tools are available and the certificate path points to the prepared PEM file. If a working connection already exists, skip its creation command and select it below. To replace its endpoint or identity, use [Optional cleanup](#optional-cleanup) for that connection first.

### 2. Create the Supervisor connection

**Official procedure:** [Connect to the Supervisor as a vCenter Single Sign-On User][supervisor-login].

```powershell
# Create the local Supervisor connection with SSO authentication and certificate verification.
vcf context create supervisor `
    --endpoint https://$SUPERVISOR_API_ENDPOINT `
    --username $VCF_CLI_VSPHERE_USERNAME `
    --ca-certificate $CERTIFICATE_FILE `
    --type k8s `
    --auth-type basic
```

Enter the SSO password when prompted and wait for successful completion. Resolve any reported certificate, authentication or permission error before continuing. PowerShell does not necessarily stop after a native CLI command fails.

### 3. Select the Supervisor and verify its API

```powershell
# List the VCF contexts created by the login operation.
vcf context list --wide

# Select the Supervisor for subsequent VCF CLI operations.
vcf context use supervisor

# Select the same Supervisor for subsequent Kubernetes commands.
kubectl config use-context supervisor

# Confirm that the active Kubernetes context is supervisor.
kubectl config current-context

# Display the API endpoint associated with the selected context.
kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"

# Request nodes from the Supervisor API.
kubectl get nodes
```

Confirm `current-context` reports `supervisor`, the server matches the intended Supervisor endpoint, and the node query reaches that API. Inspect each command's result before continuing; [Verify access](#verify-access) explains the success conditions and permission errors.

### 4. Create the DEV workload connection

**Official procedure:** [Log in to a VKS Cluster Using vCenter Single Sign-On Credentials][vks-login]. The named VKS cluster and Supervisor namespace must already exist.

```powershell
# Create a local connection to the existing DEV cluster through its Supervisor.
vcf context create $CLUSTER_NAME `
    --endpoint https://$SUPERVISOR_API_ENDPOINT `
    --username $VCF_CLI_VSPHERE_USERNAME `
    --workload-cluster-namespace $CLUSTER_NAMESPACE `
    --workload-cluster-name $CLUSTER_NAME `
    --ca-certificate $CERTIFICATE_FILE `
    --type k8s `
    --auth-type basic
```

Enter the SSO password when prompted and wait for successful completion. `--endpoint` identifies the Supervisor; the workload flags identify the target VKS cluster and its namespace.

### 5. Select the DEV workload context and verify its API

```powershell
# List VCF connections and the exact workload context names.
vcf context list --wide

# Select the workload context for VCF CLI operations.
vcf context use "$($CLUSTER_NAME):$CLUSTER_NAME"

# Select the workload context for Kubernetes commands.
kubectl config use-context "$($CLUSTER_NAME):$CLUSTER_NAME"

# Confirm the selected workload Kubernetes context.
kubectl config current-context

# Display the workload API endpoint recorded in kubeconfig.
kubectl config view --minify -o jsonpath="{.clusters[0].cluster.server}"

# Request nodes from the selected VKS workload cluster.
kubectl get nodes
```

For DEV, expect `dev-cluster-01:dev-cluster-01`, the DEV workload API endpoint, and DEV node names. If the actual listed context name differs, use that exact name in both selection commands.

For QA, change `$CLUSTER_NAMESPACE` to `qa-namespace` and `$CLUSTER_NAME` to `qa-cluster-02`, then repeat steps 4 and 5. Expect context `qa-cluster-02:qa-cluster-02`, the QA workload endpoint and QA nodes.

**Automated alternatives:** use the PowerShell 7 or Command Prompt examples in [Automated alternatives](#automated-alternatives). Run `.bat` examples from `cmd.exe`; they skip TLS certificate verification. These scripts delete and recreate the named local connection, so use their replacement behavior intentionally.

## Verify access

Verify **the selected context**, **the API endpoint** and **the node result**. Kubernetes context selection and the VCF CLI default are separate settings; the scripts directly select the Kubernetes context.

The manual procedures select a context before requesting node status. Use [Kubernetes context configuration][kube-contexts] for `use-context` and `view --minify`, and the [kubectl get reference][kubectl-get] for resource queries. These upstream pages document Kubernetes commands; Broadcom's login procedures document VCF authentication.

| Check | Success condition |
| --- | --- |
| Local connection | The intended entry appears in `vcf context list --wide`. |
| Kubernetes selection | `current-context` matches the intended target and the selected server is that target's API. |
| API access | The node query succeeds and returns the expected node names. |
| Node readiness | The displayed nodes have the required status; `kubectl get nodes` itself does not wait for `Ready`. |
| VCF CLI selection | When using VCF operations, its current entry matches the intended target after `vcf context use`. |

A `Forbidden` response can mean authentication succeeded but the identity cannot list nodes. Namespace access alone may not grant that cluster-level permission. A successful node query can still show `NotReady`; investigate cluster health separately.

## Manage existing contexts

These are independent operations, not a sequence to run in full. See the [context command reference][context-reference].

| Operation | Command | Purpose |
| --- | --- | --- |
| List connections | `vcf context list --wide` | Find names and endpoints. |
| Show the VCF default | `vcf context list --current` | Check the CLI selection. |
| Inspect a connection | `vcf context get supervisor` | Review local settings; avoid sharing authentication data. |
| Switch the VCF default | `vcf context use supervisor` | Select the target and authenticate as needed. |
| Unset the VCF default | `vcf context unset supervisor` | Clear that default if active; inspect kubeconfig separately. |
| Delete a connection | `vcf context delete supervisor` | Remove a local connection after reviewing the prompt. |

For a Bash authentication refresh, set `CLUSTER_NAME` to the **exact context name** returned by `vcf context list --wide`:

```bash
CLUSTER_NAME=dev-cluster-01:dev-cluster-01

# Refresh workload cluster authentication and retain error messages.
vcf context refresh ${CLUSTER_NAME} >/dev/null 2>&1
```

The redirection suppresses both standard output and errors. Check the command's exit status, then select the target and repeat [Verify access](#verify-access). For PowerShell, use `vcf context refresh dev-cluster-01:dev-cluster-01` to retain visible CLI diagnostics.

## Project files

### Repository layout

```text
.
├── Readme.md
├── 00-copy-dev-cluster-01-to-qa-cluster-02.sh
├── 01-create-supervisor-context.sh
├── 11-create-supervisor-context.ps1
├── 21-create-supervisor-context.bat
├── dev-cluster-01/
│   ├── 01-create-vks-cluster-context.sh
│   ├── 11-create-vks-cluster-context.ps1
│   └── 21-create-vks-cluster-context.bat
└── qa-cluster-02/
    ├── 01-create-vks-cluster-context.sh
    ├── 11-create-vks-cluster-context.ps1
    └── 21-create-vks-cluster-context.bat
```

The three runtimes are alternatives for each target. DEV and QA have identical script basenames; the containing directory determines the workload target.

The supplied scripts currently configure Supervisor endpoint `10.55.16.4` and SSO username `labadministrator@vsphere.local`. DEV uses `dev-namespace` / `dev-cluster-01`; QA uses `qa-namespace` / `qa-cluster-02`. These are lab configuration values, not live inventory. Edit the selected script's direct assignments before using it in another environment; passwords are intentionally omitted from this guide.

### What the context scripts do

| Stage | Current behavior |
| --- | --- |
| Check tools | Check VCF CLI and kubectl; Bash also requires OpenSSL. |
| Prepare TLS | Bash and PowerShell replace the shared temporary certificate file and retrieve the presented server certificate. Batch skips verification. |
| Replace the connection | Delete the named local connection and associated contexts with `-y`, then create it using SSO basic authentication. Bash ignores deletion errors. |
| Select Kubernetes | Run `kubectl config use-context`; the alternative VCF activation commands are commented out. |
| Query nodes | Display available Kubernetes contexts and query nodes once, without a readiness wait or retry. |

Bash enables exit-on-error and pipeline failure handling. The Windows examples do not explicitly inspect each native command's exit code. A final message alone does not establish successful access.

Bash exports credential variables; the existing PowerShell scripts use `$env:` assignments; batch uses `setlocal DisableDelayedExpansion`. Launch Bash and PowerShell examples as child processes using the invocations in the script tables.

### Local files created or updated

This access workflow produces connection configuration and certificates. It does not generate deployment manifests or saved execution reports.

| File or location | Producer | Purpose |
| --- | --- | --- |
| `~/.config/vcf/config.yaml` on macOS/Linux; `%USERPROFILE%\.config\vcf\config.yaml` on Windows | VCF CLI | Local connection settings; see the [Quick Start Guide][quick-start]. |
| `~/.kube/config`, or configured `KUBECONFIG` files | VCF CLI / kubectl | Kubernetes clusters, users, contexts and active selection. |
| `/tmp/SUPERVISOR.crt` | Bash context scripts | Retrieved certificate, replaced on each run and left in place afterward. |
| `SUPERVISOR.crt` in the OS temporary directory | PowerShell context scripts | Retrieved certificate, replaced on each run and left in place afterward. |
| `./supervisor-ca.pem` | Administrator or manual extraction | Certificate file for the manual procedure. |
| `qa-cluster-02/` | Optional copy helper | QA script folder replaced with retargeted DEV files. |

Protect connection files because they can contain authentication material. Batch scripts do not create a certificate file.

### Optional DEV-to-QA copy helper

The supplied QA scripts can be used directly. Run the helper only when you intend to rebuild their local directory from DEV.

| Stage | Current behavior |
| --- | --- |
| Replace QA files | Delete the entire `qa-cluster-02` folder beside the helper and recreate it, without confirmation, backup or a source-directory check before deletion. |
| Copy DEV | Use `rsync -av`, excluding `deployment-files/`, `output-*/`, `.terraform/`, `.terraform.*`, `.backup`, `terraform.tfstate` and `terraform.tfstate.*`. Exclusions do not preserve the already-deleted QA files. |
| Retarget names | Replace known DEV namespace, cluster, MongoDB and Assembly names in copied `.sh`, `.ps1`, `.bat` and `.tfvars` files. |
| Retain connection inputs | Copy endpoint and credentials unchanged; review them before running QA scripts. |

The helper changes local files only and prints an rsync listing and transfer summary. It does not create contexts or clusters. Confirm DEV exists and preserve needed QA edits before using it.

## Optional cleanup

Delete a local connection when it is no longer needed or must be recreated. This removes local access configuration; it does not delete the Supervisor, namespace or VKS cluster.

```bash
# Review connections before choosing one to remove.
vcf context list --wide
```

Choose one command and review the CLI confirmation:

| Local connection | Deletion command |
| --- | --- |
| Supervisor | `vcf context delete supervisor` |
| DEV | `vcf context delete dev-cluster-01` |
| QA | `vcf context delete qa-cluster-02` |

`-y` removes the prompt and includes associated Supervisor namespace or workload contexts; the example scripts already use it. `--skip-delete-kubeconfig-context` keeps the kubeconfig entry when intentionally required. Avoid deleting the whole kubeconfig file, which can contain unrelated connections.

```bash
# Review the remaining VCF connections.
vcf context list --wide

# Review the remaining Kubernetes contexts.
kubectl config get-contexts
```

Select another valid context if the removed one was active. Context deletion does not explicitly remove the retrieved certificate files; remove an unused certificate only after confirming no remaining connection needs its path.

## Troubleshooting

| Symptom | Check or action |
| --- | --- |
| Context already exists | Select the working entry, or remove only the intended connection through [Optional cleanup](#optional-cleanup). |
| Certificate file not found | Set `CERTIFICATE_FILE` before extraction or creation, and check its path relative to the terminal's working directory. |
| `x509: certificate signed by unknown authority` | Supply the required full CA chain or use the OS trust store; see [KB 460364][certificate-kb]. A retrieved server certificate can be insufficient. |
| Certificate hostname mismatch | Use an endpoint covered by the Supervisor certificate or ask the administrator to correct the certificate. |
| Browser/OIDC authentication appears unexpectedly | For the vCenter SSO flow, confirm `--auth-type basic`; see [KB 417617][basic-auth]. |
| `exec: executable vcf not found` during kubectl | Ensure VCF CLI is in the terminal's `PATH`; kubeconfig authentication can invoke it. |
| Authentication expires | Refresh the exact listed context through [Manage existing contexts](#manage-existing-contexts), then reselect it and verify access. |
| `Forbidden` when listing nodes | Confirm the identity has cluster-level node-read permission. |
| Wrong API endpoint or node names | Check `current-context` and the selected server. Select the intended Kubernetes context before retrying. |
| Workload context is absent | Confirm creation succeeded, the cluster and namespace exist, and the identity has access. Inspect both VCF and Kubernetes lists. |
| Windows example continues after an error | Review native command results and verify the target and API access before continuing. |
| Connection timeout | Check DNS, routing, firewall rules and access to both Supervisor and workload APIs. |
| Manual variables do not affect a script | Edit the direct assignments inside the selected file. |
| Bash stops during certificate retrieval | Check TCP 443, OpenSSL and write access to `/tmp/SUPERVISOR.crt`. Retrieval precedes context deletion; pipeline errors stop the script. |
| Node is `NotReady` after a successful query | The scripts display status once; investigate cluster health separately. |
| QA edits disappear after the copy helper | The helper deletes the entire QA folder first. Restore needed files from your backup; rsync exclusions do not retain them. |

## References

Use the links below to locate the official procedures underlying the manual steps. Destination content was reviewed on **2026-11-18**. Broadcom VCF Consumption `latest`, the developer Quick Start and the Kubernetes pages are rolling documentation; check the installed CLI help for your version.

The Bash and PowerShell sections adapt the same Broadcom login procedures to each shell. They add explicit local names, `--type k8s`, SSO basic authentication, and target verification. The optional server-certificate extraction examples are local preparation examples; Broadcom's secure-login procedure explains the required trust configuration.

| Reference | What it covers |
| --- | --- |
| [Supervisor login — Connect to the Supervisor as a vCenter Single Sign-On User][supervisor-login] | **Manual steps 2–3** on both platforms: obtain prerequisites, create the Supervisor connection, enter SSO credentials, list contexts and select the target. |
| [VKS login — Log in to a VKS Cluster Using vCenter Single Sign-On Credentials][vks-login] | **Manual steps 4–5** on both platforms: create the workload connection through the Supervisor using namespace and cluster flags, authenticate, list and select contexts. |
| [Prepare certificate trust — Configure Secure Login for vSphere Supervisor][secure-login] | **Certificate preparation:** the Supervisor CA Certificate and VKS Cluster CA Certificate sections explain trust requirements. |
| [Download vCenter root certificates — KB 330833, Certificate Download in Small Deployments][root-ca] | **Obtain the CA:** browser download, ZIP extraction, certificate/CRL identification and workstation trust configuration. Linked from Broadcom's secure-login guide. |
| [Create a connection — VCF CLI `context create`][context-create] | **Command arguments:** local connection name, endpoint, authentication type, certificate path and workload-selection flags. |
| [Select a connection — VCF CLI `context use`][context-use] | **Manual steps 3 and 5:** set the VCF CLI default context. |
| [Manage connections — VCF CLI context command reference][context-reference] | **Existing contexts and cleanup:** list, get, refresh, unset and delete; includes `-y` and kubeconfig-retention behavior. |
| [Select and inspect Kubernetes contexts — Configure Access to Multiple Clusters][kube-contexts] | **API verification:** `kubectl config use-context`, kubeconfig relationships and `view --minify`. |
| [Query Kubernetes resources — kubectl get][kubectl-get] | **API verification:** resource-query syntax, output options and request behavior for commands such as `kubectl get nodes`. |
| [VCF CLI Quick Start Guide][quick-start] | Context types, basic workflows and local configuration locations. |
| [Use vCenter SSO explicitly — KB 417617][basic-auth] | Why `--auth-type basic` selects vCenter SSO instead of automatically using VCF Automation's identity provider. |
| [Resolve certificate-trust errors — KB 460364][certificate-kb] | Full PEM CA chains and the operating-system trust alternative to an explicit certificate file. |

[supervisor-login]: https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vsphere-kuberenetes-service-clusters-and-workloads/configuring-identity-and-access-for-tkg-service-clusters/connecting-to-vsphere-with-tanzu-clusters/connect-to-the-supervisor-cluster-as-a-vcenter-single-sign-on-user.html
[vks-login]: https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vsphere-kuberenetes-service-clusters-and-workloads/configuring-identity-and-access-for-tkg-service-clusters/connecting-to-vsphere-with-tanzu-clusters/connect-to-a-tkg-service-cluster-as-a-vcenter-single-sign-on-user-with-kubectl/log-in-using-credentials.html
[context-reference]: https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/consumer-interfaces-in-vcf/installing-and-using-vcf-cli-v9/command-reference2/system-commands(1)/context2.html
[quick-start]: https://developer.broadcom.com/xapis/vcf-cli-api/latest/api-docs.html
[secure-login]: https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vsphere-kuberenetes-service-clusters-and-workloads/configuring-identity-and-access-for-tkg-service-clusters/connecting-to-vsphere-with-tanzu-clusters/configure-secure-login-for-vsphere-with-kubernetes-clusters.html
[basic-auth]: https://knowledge.broadcom.com/external/article/417617
[certificate-kb]: https://knowledge.broadcom.com/external/article/460364/troubleshooting-x509-certificate-signed.html

[context-create]: https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/consumer-interfaces-in-vcf/installing-and-using-vcf-cli-v9/command-reference2/system-commands(1)/context2.html#GUID-c8090605-156e-4abd-951f-658965562e27-en_id-b8cd7cc9-0cfc-40ca-ffc1-71747443ecdf
[context-use]: https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/consumer-interfaces-in-vcf/installing-and-using-vcf-cli-v9/command-reference2/system-commands(1)/context2.html#GUID-c8090605-156e-4abd-951f-658965562e27-en_id-54ea4830-8080-4be4-abe9-7f472b23913c
[root-ca]: https://knowledge.broadcom.com/external/article?articleNumber=330833#certificate_download_in_small_deployments
[kube-contexts]: https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/
[kubectl-get]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/
