# vroom-infra

## About Vroom

**Vroom** is a cloud-native MVP built to explore the full DevOps lifecycle — CI/CD, GitOps, progressive delivery, observability, and AI-assisted incident response — under a hard **12 GB RAM** budget across 3 VMs, running on **K3s** instead of full Kubernetes.

The ride-hailing domain (passengers, drivers, trip matching) is a realistic placeholder application — enough business logic to justify real microservices patterns (event-driven architecture, sagas, the outbox pattern). The actual subject of this project is the platform built around it: how the app is shipped, deployed, observed, and kept alive.

This is a 3-repo GitOps setup, each repo with a single responsibility:

| Repo | Responsibility |
|---|---|
| [vroom-services](https://github.com/Ama2352/vroom-services) | Go microservices + Python incident agent + React frontend + CI pipeline |
| [vroom-gitops](https://github.com/Ama2352/vroom-gitops) | Kustomize + ArgoCD + Kargo — CD pipeline environment |
| **vroom-infra** (this repo) | Vagrant + Ansible — K3s cluster bootstrap |

## This Repo

Provisions the underlying K3s cluster the rest of the platform runs on — Vagrant VMs + Ansible playbooks, treated as immutable infrastructure. `vagrant up` produces a running cluster with ArgoCD already bootstrapped; from there, GitOps ([vroom-gitops](https://github.com/Ama2352/vroom-gitops)) takes over.

---

## Tech Stack

| Category | Technology |
|---|---|
| Virtualization | Vagrant + VMware Desktop provider (`bento/ubuntu-22.04`) |
| Provisioning | Ansible (`ansible_local`, no SSH key management between VMs) |
| Orchestration | K3s (lightweight Kubernetes) |
| Bootstrap | ArgoCD + Sealed Secrets controller (installed via Ansible, then GitOps takes over) |
| Secrets | Sealed Secrets (`kubeseal`), rendered from Jinja2 templates |

---

## Key Features

- Immutable infrastructure — `vagrant destroy && vagrant up` reproduces a running cluster with no manual `kubectl` steps
- K3s chosen for its ~512 MB control-plane footprint vs ~2 GB for kubeadm, under a 12 GB total budget
- `ansible_local` — each VM provisions itself; no SSH key distribution needed from the host
- Fully automated bootstrap chain: k3s-server → agents join → ArgoCD + Sealed Secrets install → `root-app.yaml` applied, unattended
- One-command secret sealing (`seal-secrets.yml`) pushes encrypted manifests straight to vroom-gitops

---

## Infrastructure Model

The cluster is treated as **immutable infrastructure**: re-provisioning from scratch (`vagrant destroy && vagrant up`) should reproduce a running cluster. No manual `kubectl` steps after initial bootstrap.

### Why K3s, not full Kubernetes

Hard constraint: 12 GB RAM across 3 VMs. K3s uses ~512 MB for the control plane vs ~2 GB for kubeadm. This constraint also drove Go over Java and removed Istio (service mesh overhead ~200 MB/pod).

### Why Ansible runs inside VMs

Vagrant's `ansible_local` provisioner is used so the Windows host does not need a POSIX Ansible installation. Each VM installs Ansible itself, then runs its own playbook over `--connection=local`. No SSH key management between VMs.

### What's in `ansible/`

Everything under `ansible/` is a set of playbooks that Vagrant drives — you never run `ansible-playbook` by hand for the normal flow:

| Playbook | Runs when | What it does |
|----------|-----------|---------------|
| `playbooks/k3s-server.yml` | Automatically, during `vagrant up` | Installs the K3s server, writes a join-token script to `/vagrant/` |
| `playbooks/k3s-agent.yml` | Automatically, during `vagrant up` | Waits for the join script, joins each agent to the cluster |
| `playbooks/argocd.yml` | Automatically, triggered right after the last agent joins | Installs ArgoCD + the Sealed Secrets controller (Helm), then applies `root-app.yaml` from vroom-gitops — GitOps takes over from here |
| `playbooks/seal-secrets.yml` | Manually, only when you want real secrets in the cluster | Reads `ansible/vars/secrets.yml`, seals each value with `kubeseal`, pushes the sealed manifests straight to `vroom-gitops/secrets/` |
| `playbooks/gitlab-runner.yml` | Manually, optional | Installs a self-hosted GitLab Runner on `k3s-server` (only needed if you don't want to use GitLab's shared runners) |

`ansible/templates/db-secret.j2` and `ansible/vars/` are just inputs to `seal-secrets.yml` — a Jinja2 template for the per-service DB Secret shape, and the plaintext values it renders from.

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
                                └── argocd.yml   Install ArgoCD + Sealed Secrets controller;
                                                  apply root-app.yaml
                                                        │
                                                 GitOps takes over
```

That's the entire cluster bootstrap — `vagrant up` alone gets you a running K3s cluster with ArgoCD reconciling everything from vroom-gitops. No secrets, no manual `kubectl`, no extra flags. Sealing and pushing real secrets (DB passwords, Slack webhook, GHCR/GitHub tokens, …) is a separate, optional follow-up step — see [Seal secrets](#seal-secrets) below.

---

## Cluster Topology

| VM | Role | IP | RAM |
|----|------|----|-----|
| `k3s-server` | Control plane + workloads | 192.168.242.10 | 4 GB |
| `k3s-agent-1` | Worker | 192.168.242.11 | 4 GB |
| `k3s-agent-2` | Worker | 192.168.242.12 | 4 GB |

**Total: 12 GB** — hard RAM ceiling that drives every platform sizing decision.

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
└── secrets/
    └── raw-template.yaml       Reference template for adding new SealedSecret entries
```

---

## Provision the cluster

**Prerequisites:** VMware Desktop (Workstation or Fusion) + [vagrant-vmware-desktop plugin](https://developer.hashicorp.com/vagrant/docs/providers/vmware), 12 GB RAM free on the host.

```bash
vagrant up
```

That's the whole thing — no config to edit first. Vagrant runs the entire provisioning sequence on its own: creates the 3 VMs, installs K3s on the server, joins both agents, then installs ArgoCD + Sealed Secrets and applies `root-app.yaml`. A few minutes later you have a fully reconciling cluster.

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

The cluster is up after `vagrant up`, but apps that need real credentials (DB passwords, Slack webhook, GHCR/GitHub tokens, Kargo admin login, …) won't work until secrets are sealed and pushed. This is a separate, one-time step:

```bash
# 1. Fill in plaintext secret values (gitignored — never commit this file)
cp ansible/vars/secrets.yml.example ansible/vars/secrets.yml
# edit ansible/vars/secrets.yml with real values

# 2. Seal every value with kubeseal and push the sealed manifests to vroom-gitops/secrets/
vagrant provision k3s-server --provision-with seal-secrets
```

ArgoCD picks up the pushed secrets within ~3 minutes (the `vroom-secrets` Application auto-syncs). Re-run the same command any time a value in `secrets.yml` changes, or after `vagrant destroy && vagrant up` recreates the cluster.

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
