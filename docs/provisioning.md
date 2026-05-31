# Provisioning Walkthrough

## Prerequisites

- VMware Desktop (Workstation or Fusion) + Vagrant VMware plugin
- 12 GB RAM free on the host
- `vagrant plugin install vagrant-vmware-desktop`

## First-time setup

```bash
# Clone the repo
git clone https://github.com/Ama2352/vroom-infra
cd vroom-infra

# Copy secrets template and fill in values
cp ansible/vars/secrets.yml.example ansible/vars/secrets.yml
# Edit secrets.yml with real DB passwords, Slack webhook, GHCR token, etc.

# Start the cluster
vagrant up
```

Vagrant automatically:
1. Creates 3 VMs with Ubuntu 22.04
2. Runs `k3s-server.yml` on the server (installs K3s, writes join token)
3. Runs `k3s-agent.yml` on both agents (joins the cluster)
4. After the second agent joins, triggers `argocd.yml` on the server (installs ArgoCD, applies root-app.yaml)

## Access the cluster

```bash
export KUBECONFIG=$(pwd)/ansible/k3s.yaml
kubectl get nodes
# NAME          STATUS   ROLES                  AGE
# k3s-server    Ready    control-plane,master   5m
# k3s-agent-1   Ready    <none>                 3m
# k3s-agent-2   Ready    <none>                 3m
```

## Service access

| Service | URL |
|---------|-----|
| ArgoCD UI | `https://192.168.242.10` |
| Grafana | `http://192.168.242.10/grafana` |
| Kargo UI | `https://192.168.242.10:30088` |
| n8n | `http://192.168.242.10/n8n/` |
| Prometheus | `kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090` |

## Teardown

```bash
vagrant destroy -f
```
