# vroom-infra

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Vagrant + Ansible provisioning for the **Vroom** K3s cluster. Declares three VMs that assemble into a K3s cluster and bootstraps ArgoCD — from there, GitOps takes over and ArgoCD deploys everything else from [vroom-gitops](https://github.com/Ama2352/vroom-gitops).

Part of a three-repo setup:

| Repo | Responsibility |
|------|---------------|
| [vroom-services](https://github.com/Ama2352/vroom-services) | Application source code + CI pipeline |
| [vroom-gitops](https://github.com/Ama2352/vroom-gitops) | Cluster manifests — ArgoCD reads and reconciles this |
| **vroom-infra** (this repo) | Vagrant + Ansible K3s provisioning |

---

## Infrastructure Model

The cluster is treated as **immutable infrastructure**: re-provisioning from scratch (`vagrant destroy && vagrant up`) should reproduce a running cluster. No manual `kubectl` steps after initial bootstrap.

### Why K3s, not full Kubernetes

Hard constraint: 10 GB RAM across 3 VMs. K3s uses ~512 MB for the control plane vs ~2 GB for kubeadm. This constraint also drove Go over Java and removed Istio (service mesh overhead ~200 MB/pod).

### Why Ansible runs inside VMs

Vagrant's `ansible_local` provisioner is used so the Windows host does not need a POSIX Ansible installation. Each VM installs Ansible itself, then runs its own playbook over `--connection=local`. No SSH key management between VMs.

### Provisioning sequence

```
vagrant up
  ├── k3s-server VM starts (Ubuntu 22.04)
  │     └── k3s-server.yml    Install K3s server; write join script to /vagrant/
  ├── k3s-agent-1 VM starts
  │     └── k3s-agent.yml     Wait for join script; join cluster
  └── k3s-agent-2 VM starts
        └── k3s-agent.yml     Wait for join script; join cluster
              └── (trigger)   After last agent: run argocd.yml on k3s-server
                                └── argocd.yml   Install ArgoCD; apply root-app.yaml
                                                        │
                                                 GitOps takes over
```

---

## Cluster Topology

| VM | Role | IP | RAM |
|----|------|----|-----|
| `k3s-server` | Control plane + workloads | 192.168.242.10 | 3.5 GB |
| `k3s-agent-1` | Worker | 192.168.242.11 | 3.5 GB |
| `k3s-agent-2` | Worker | 192.168.242.12 | 3.5 GB |

**Total: ~10.5 GB** — hard RAM ceiling that drives every platform sizing decision.

---

## Repository Layout

```
vroom-infra/
├── Vagrantfile                 VM definitions (VMware Desktop provider)
│                               Provisions: k3s-server → agents → argocd (sequential)
├── ansible/
│   ├── playbooks/
│   │   ├── k3s-server.yml      Install K3s server, generate join token script
│   │   ├── k3s-agent.yml       Poll for join script, join cluster
│   │   ├── argocd.yml          Install ArgoCD, apply root-app.yaml from vroom-gitops
│   │   └── seal-secrets.yml    Render plaintext secrets → kubeseal → push to vroom-gitops
│   ├── templates/
│   │   └── db-secret.j2        Jinja2 template for Kubernetes Secret manifests
│   └── vars/
│       └── secrets.yml.example Fill in values before running seal-secrets.yml
├── scripts/
│   ├── apply-sealed-secrets.ps1  Windows fallback — apply pre-sealed secrets directly
│   ├── install-kargo-cli.sh      Installs the Kargo CLI inside a VM, version-pinned to the Helm chart
│   └── setup-ngrok.sh            Expose cluster port for external testing
├── secrets/
│   └── raw-template.yaml       Reference template for adding new SealedSecret entries
├── LICENSE
└── docs/
    └── KARGO_CLI_GUIDE.md      Kargo CLI installation, command reference, and troubleshooting
```

---

## Provision the cluster

**Prerequisites:** VMware Desktop (Workstation or Fusion) + [vagrant-vmware-desktop plugin](https://developer.hashicorp.com/vagrant/docs/providers/vmware), 12 GB RAM free on the host.

```bash
# 1. Fill in plaintext secret values (gitignored)
cp ansible/vars/secrets.yml.example ansible/vars/secrets.yml
# edit secrets.yml with DB passwords, Slack webhook URL, GHCR token, etc.

# 2. Start the cluster — Vagrant runs the full provisioning sequence
vagrant up
```

Vagrant automatically:
1. Creates 3 VMs with Ubuntu 22.04
2. Runs `k3s-server.yml` on the server (installs K3s, writes join token)
3. Runs `k3s-agent.yml` on both agents (joins the cluster)
4. After the second agent joins, triggers `argocd.yml` on the server (installs ArgoCD, applies `root-app.yaml`)

To re-run a single playbook after provisioning:

```bash
vagrant ssh k3s-server
ansible-playbook /vagrant/ansible/playbooks/k3s-server.yml --connection=local
ansible-playbook /vagrant/ansible/playbooks/argocd.yml --connection=local
```

Teardown:

```bash
vagrant destroy -f
```

---

## Seal secrets

```bash
# Renders plaintext values from ansible/vars/secrets.yml → SealedSecrets → pushes to vroom-gitops
vagrant provision --provision-with seal-secrets.yml
```

Windows fallback (applies pre-sealed secrets directly, no re-sealing):

```powershell
./scripts/apply-sealed-secrets.ps1
```

---

## Access the cluster

```bash
export KUBECONFIG=$(pwd)/ansible/k3s.yaml
kubectl get nodes
```

| Service | URL |
|---------|-----|
| ArgoCD UI | `https://192.168.242.10` |
| Grafana | `http://192.168.242.10/grafana` |
| Kargo UI | `https://192.168.242.10:30088` |
| n8n | `http://192.168.25.139:30078/` (NodePort — sub-path routing via Traefik is broken due to Vite's absolute asset paths) |
| Prometheus | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090` |

---

## Documentation

- [Kargo CLI reference](docs/KARGO_CLI_GUIDE.md) — installation, command reference, verification troubleshooting
