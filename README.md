# Vroom Infrastructure: 3-Node K3s Cluster

This repository contains the Infrastructure-as-Code (IaC) required to provision and configure the private cloud environment for the **Vroom** platform.

## 📐 Architecture

The infrastructure is designed to run on a local VMware hypervisor, optimized for high-density microservices.

- **3 Nodes**: `k3s-server`, `k3s-agent-1`, `k3s-agent-2`.
- **Resources**: Each node is allocated **3.5GB RAM** (3584 MB) and **2 vCPUs**.

## 🛠️ Tech Stack

- **Vagrant**: Virtual machine orchestration.
- **Ansible**: Configuration management and cluster bootstrapping.
- **K3s**: Lightweight Kubernetes distribution.
- **Sealed Secrets**: Secure secret management for GitOps.

## 🚀 Quick Start

### 1. Prepare Secrets

Before provisioning, you must provide the raw secrets.

- Create a `.secrets/` directory in the root of this repo.
- Populate it with the necessary credential files (refer to the `secrets/` template directory for required files).
- These will be automatically encrypted into **SealedSecrets** during the provisioning phase.

### 2. Provision Cluster

Run the following command. Vagrant will automatically provision the VMs and execute the Ansible playbooks to setup K3s, ArgoCD, Kargo, and deploy the root applications.

```bash
vagrant up
```

### 3. Apply Sealed Secrets

Once `vagrant up` completes, you need to move the newly generated sealed secrets to your GitOps repository:

```powershell
# Ensure vroom-gitops is cloned in the same workspace folder
.\scripts\apply-sealed-secrets.ps1
```

This script automates the process of copying the encrypted secrets to `vroom-gitops`, committing them, and pushing them to GitHub for ArgoCD to synchronize.

### 4. Accessing the Cluster

Extract the kubeconfig to your host:

```bash
$env:KUBECONFIG = "$(Get-Location)\ansible\k3s.yaml"
kubectl get nodes
```

## 🔗 Related Repositories

- **[vroom-services](https://github.com/Ama2352/vroom-services)**: Application code and CI.
- **[vroom-gitops](https://github.com/Ama2352/vroom-gitops)**: The GitOps "Source of Truth".
