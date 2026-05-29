# vroom-infra

Vagrant + Ansible provisioning for the **Vroom** K3s cluster. Spins up 3 VMs and installs a fully configured K3s cluster with ArgoCD bootstrapped.

Part of a three-repo setup:
- [vroom-services](https://github.com/Ama2352/vroom-services) — application source + CI
- [vroom-gitops](https://github.com/Ama2352/vroom-gitops) — delivery manifests
- **vroom-infra** (this repo) — cluster provisioning

---

## Cluster Topology

| VM | Role | IP | RAM |
|----|------|----|-----|
| `k3s-server` | Control plane + workloads | 192.168.25.133 | 3.5 GB |
| `k3s-agent-1` | Worker | 192.168.25.134 | 3.5 GB |
| `k3s-agent-2` | Worker | 192.168.25.135 | 3.5 GB |

**Total: 10.5 GB RAM** — hard constraint driving all platform sizing decisions.

---

## Repository Layout

```
vroom-infra/
├── Vagrantfile             VM definitions (VMware Desktop provider)
├── ansible/
│   ├── playbooks/          Ansible playbooks
│   │   ├── k3s-server.yml  Install K3s server, generate join script
│   │   ├── k3s-agent.yml   Join agents to cluster
│   │   ├── argocd.yml      Bootstrap ArgoCD + apply root-app
│   │   └── seal-secrets.yml  Seal and push SealedSecrets to vroom-gitops
│   ├── templates/          Jinja2 templates (db-secret.j2)
│   └── vars/
│       └── secrets.yml.example  Fill in plaintext values before sealing
├── scripts/
│   ├── apply-sealed-secrets.ps1  Windows fallback — apply secrets without re-sealing
│   └── setup-ngrok.sh            Expose cluster port for external testing
├── secrets/
│   └── raw-template.yaml   Reference template for new SealedSecret entries
└── docs/
    └── KARGO_CLI_GUIDE.md  Kargo CLI installation and usage reference
```

---

## Provision the cluster

```bash
# 1. Start all VMs (Vagrant provisions k3s-server and agents automatically)
vagrant up

# 2. Ansible runs inside each VM (not from the Windows host).
#    If you need to re-run a playbook manually:
vagrant ssh k3s-server
ansible-playbook /vagrant/ansible/playbooks/k3s-server.yml --connection=local
ansible-playbook /vagrant/ansible/playbooks/argocd.yml --connection=local

vagrant ssh k3s-agent-1 -c "ansible-playbook /vagrant/ansible/playbooks/k3s-agent.yml --connection=local"
vagrant ssh k3s-agent-2 -c "ansible-playbook /vagrant/ansible/playbooks/k3s-agent.yml --connection=local"

# 3. Access cluster from Windows host
export KUBECONFIG=$(pwd)/ansible/k3s.yaml
kubectl get nodes
```

---

## Seal secrets

Fill in `ansible/vars/secrets.yml` (gitignored), then:

```bash
vagrant provision --provision-with seal-secrets.yml
```

Or use the Windows PowerShell fallback to apply pre-sealed secrets directly:

```powershell
./scripts/apply-sealed-secrets.ps1
```

---

## Documentation

- [Kargo CLI reference](docs/KARGO_CLI_GUIDE.md)
- [Provisioning walkthrough](docs/provisioning.md)
