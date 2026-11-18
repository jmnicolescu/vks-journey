<!--
authors: "Julius M. Nicolescu, Qwen3-Coder-30B-A3B-Instruct-4bit, Qwen3.8-27B-8bit"
date: 2026-11-18
description: A practical guide to deploying and operating VMware vSphere Kubernetes Service (VKS) on VMware Cloud Foundation (VCF) 9.1.1, from administrative access and cluster creation to applications and add-ons.
keywords: VKS, VMware Cloud Foundation, VCF 9.1.1, Kubernetes, Terraform, automation, cert-manager, Contour, Istio, Gateway API, POC, POV
lang: en
-->

# VKS Journey — From Deployment to Real-World Solutions

A practical guide to deploying and operating VMware vSphere Kubernetes Service (VKS) on VMware Cloud Foundation (VCF) 9.1.1, from administrative access and cluster creation to applications and add-ons.

The repository provides step-by-step guides, example scripts, Kubernetes manifests, and Terraform configurations for DEV and QA environments. Use the projects to build a Proof of Concept (POC) or Proof of Value (POV), from cluster provisioning and persistent applications to HTTP/HTTPS routing with Contour or Istio.

## GitHub repository

Repository: **[jmnicolescu/vks-journey](https://github.com/jmnicolescu/vks-journey)**.

Each numbered directory groups the files and README for one project. In the table below, select a project name to explore its files or **Project guide** to review prerequisites and follow the configuration, deployment, and verification steps.

## Contents

- [Purpose and objectives](#purpose-and-objectives)
- [Projects](#projects)

## Purpose and objectives

Moving from a configured VCF platform to a working Kubernetes application involves identity, workstation tools, cluster access, namespaces, compute, networking, and storage. These projects cover that journey on an existing Supervisor, with separate guides for each task and its dependencies.

The objectives are to:

- Prepare administrative access and install the tools used to manage VKS.
- Configure Supervisor access, create vSphere namespaces, and deploy DEV and QA VKS clusters.
- Deploy applications that demonstrate workload scheduling, persistent storage, and external LoadBalancer access.
- Install cert-manager, Contour, or Istio add-ons and publish applications through Gateway API with HTTP/HTTPS routing and TLS certificates.
- Explore a shared Contour Gateway and shared or dedicated Istio Gateways, then verify routes, listeners, and application access.
- Support repeatable demonstrations, troubleshooting, POCs, and POVs through reusable examples and verification procedures.

## Projects

The project directories below match the current repository. Each guide describes the available manual procedures and automation alternatives; supported tools and platforms vary by project.

<table>
  <thead>
    <tr>
      <th width="35%" align="left">Project name</th>
      <th width="65%" align="left">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td valign="top"><strong><a href="40-create-vcenter-users/">Create vCenter users</a></strong></td>
      <td valign="top">
        <p>Creates vCenter SSO lab users and groups and configures administrator permissions for vCenter and Supervisor. Explains the read-only access model for namespaces and VKS workloads, with vSphere Client, Bash, and independent Terraform configurations for user creation and DEV/QA workload access, plus verification and cleanup.</p>
        <p><a href="40-create-vcenter-users/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="41-install-vcf-cli-kubectl/">Install VCF CLI and kubectl</a></strong></td>
      <td valign="top">
        <p>Installs VCF Consumption CLI, kubectl, and VCF CLI plugins on macOS, Linux, or Windows. Covers manual installation and platform-specific scripts, downloads from Supervisor and Broadcom Support, alternative Kubernetes client downloads, and local verification.</p>
        <p><a href="41-install-vcf-cli-kubectl/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="42-create-vks-context/">Create Supervisor and VKS contexts</a></strong></td>
      <td valign="top">
        <p>Creates and selects local VCF CLI connections to an existing Supervisor and DEV and QA VKS clusters. Covers certificates, authentication, Kubernetes context selection, and access verification using manual commands or Bash, PowerShell, and Command Prompt examples.</p>
        <p><a href="42-create-vks-context/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="43-create-vsphere-namespace/">Create vSphere namespaces</a></strong></td>
      <td valign="top">
        <p>Creates DEV and QA vSphere namespaces on an existing Supervisor and configures access, storage policies, quotas, and VM classes. Covers vSphere Client, Bash, PowerShell, Command Prompt, Terraform, and a self-service alternative using a namespace template.</p>
        <p><a href="43-create-vsphere-namespace/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="44-create-vks-cluster/">Create VKS clusters</a></strong></td>
      <td valign="top">
        <p>Creates <code>dev-cluster-01</code> and <code>qa-cluster-02</code> in their respective vSphere namespaces using YAML, Bash, PowerShell, Command Prompt, or Terraform. Covers Supervisor access, cluster provisioning, availability checks, workload cluster connections, and optional deletion.</p>
        <p><a href="44-create-vks-cluster/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="45-deploy-assembly-webapp-lb/">Deploy Assembly web application</a></strong></td>
      <td valign="top">
        <p>Deploys Assembly Web App to a DEV or QA VKS cluster with an application namespace, three web replicas, and a LoadBalancer Service. Includes manual deployment, Bash, PowerShell, Command Prompt, and standalone Terraform alternatives, plus access verification and cleanup.</p>
        <p><a href="45-deploy-assembly-webapp-lb/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="46-deploy-mongo-espress-lb/">Deploy MongoDB and Mongo Express</a></strong></td>
      <td valign="top">
        <p>Deploys MongoDB with persistent storage and the Mongo Express web interface to a DEV or QA VKS cluster. Demonstrates internal service connectivity and external LoadBalancer access using YAML, Bash, PowerShell, Command Prompt, or Terraform, with verification and cleanup.</p>
        <p><a href="46-deploy-mongo-espress-lb/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="47-install-vks-addon-contour/">Install cert-manager and Contour add-ons</a></strong></td>
      <td valign="top">
        <p>Installs cert-manager and Contour with Envoy on DEV and QA VKS clusters. Covers manual procedures and Bash examples, a static shared Gateway with wildcard or individual TLS certificates, HTTP-to-HTTPS redirects, and Assembly WebApp and Mongo Express routing, verification, and cleanup.</p>
        <p><a href="47-install-vks-addon-contour/Readme.md">Project guide</a></p>
      </td>
    </tr>
    <tr>
      <td valign="top"><strong><a href="48-install-vks-addon-istio/">Install the Istio add-on</a></strong></td>
      <td valign="top">
        <p>Installs Istio on DEV and QA VKS clusters and publishes Assembly WebApp and Mongo Express through Gateway API. Covers manual procedures and Bash examples, shared or dedicated Envoy Gateways, HTTP/HTTPS listeners, TLS certificates, application verification, and cleanup.</p>
        <p><a href="48-install-vks-addon-istio/Readme.md">Project guide</a></p>
      </td>
    </tr>
  </tbody>
</table>
