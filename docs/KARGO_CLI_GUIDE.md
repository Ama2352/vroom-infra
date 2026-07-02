# Kargo CLI Guide (VM-Based)

This guide explains how to install and use the Kargo CLI inside the `k3s-server` VM. The CLI version must match the Kargo Helm chart version deployed in the cluster (`v1.10.3` — see `vroom-gitops/platform/kargo-chart/kargo-chart.yaml`).

---

## 1. Installation

From your host machine:

```powershell
cd vroom-infra
vagrant ssh k3s-server
```

Once inside the VM, run the install script (idempotent — upgrades if already installed at a different version):

```bash
cd /vagrant
chmod +x install-kargo-cli.sh
./install-kargo-cli.sh
```

Verify:

```bash
kargo version
```

> **Version alignment:** The script installs `v1.10.3`. If the Helm chart is ever upgraded, update `KARGO_VERSION` in `install-kargo-cli.sh` to match and re-run it. CLI and server versions must match.

---

## 2. Retrieve the Admin Password

The admin password is stored in a Kubernetes secret:

```bash
kubectl get secret kargo-admin-secret -n vroom-kargo \
  -o jsonpath='{.data.ADMIN_ACCOUNT_PASSWORD}' | base64 -d
echo  # add newline
```

---

## 3. Login

Use the NodePort URL (accessible from inside the VM, which is the k3s-server node):

```bash
kargo login https://192.168.242.10:30088 \
  --admin \
  --password <password> \
  --insecure-skip-tls-verify
```

The session token is cached at `~/.kargo/config`. Re-login if commands return `unauthenticated`.

> **Note:** The cluster-internal DNS address `kargo-api.vroom-kargo.svc.cluster.local` is not reliably resolvable from the VM's bash shell. Use the NodePort URL above instead.

---

## 4. Command Reference

### Core Resources

| Action | Command |
| :--- | :--- |
| Check CLI version | `kargo version` |
| List projects | `kargo get projects` |
| Inspect Warehouse | `kargo get warehouses --project vroom` |
| List all Freight | `kargo get freight --project vroom` |
| Freight available to a stage | `kargo get freight --project vroom --stage dev` |
| List Stages (with status) | `kargo get stages --project vroom` |
| Inspect a single Stage | `kargo get stage dev --project vroom` |
| List Promotions for a Stage | `kargo get promotions --project vroom --stage dev` |

### Promotion Actions

| Action | Command |
| :--- | :--- |
| Auto-trigger a manual promotion | `kargo promote --project vroom --stage <stage> --freight <id>` |
| Approve Freight for prod (manual gate) | `kargo approve --project vroom --stage prod --freight <id>` |
| Force Warehouse re-poll | `kargo refresh warehouse vroom-warehouse --project vroom` |
| Force Stage re-run | `kargo refresh stage dev --project vroom` |

### Inspecting Verifications

Kargo runs verifications using Argo Rollouts `AnalysisRun` resources. When a verification shows `Failed` or stalls, inspect it directly:

```bash
# List all AnalysisRuns in the Kargo namespace
kubectl get analysisruns -n vroom-kargo

# Full details for a specific run (metric values, error messages)
kubectl describe analysisrun <name> -n vroom-kargo

# Raw YAML for the full status block
kubectl get analysisrun <name> -n vroom-kargo -o yaml | grep -A 30 "status:"
```

---

## 5. UI Access

**URL:** `https://192.168.242.10:30088`
**User:** `admin`
**Password:** retrieve via the `kubectl` command in section 2 above.

---

## 6. How Kargo Interacts with ArgoCD

Kargo does **not** rely on ArgoCD's auto-sync to detect gitops changes. The promotion flow is:

1. Kargo's `git-push` promotion step writes updated image tags to the gitops overlay in vroom-gitops.
2. Kargo's `argocd-update` promotion step calls the ArgoCD API directly to trigger a sync of the target applications. It waits for ArgoCD to reach the specific commit SHA output by the preceding `git-commit` step via `desiredRevision: ${{ outputs.commit.commit }}`.
3. ArgoCD performs the sync and reports status back to Kargo.

**Staging and prod** ApplicationSets are configured with `automated: false` / `selfHeal: false`. ArgoCD will not auto-sync these environments — Kargo is the sole owner of promotion decisions.

**Dev** has auto-sync enabled, so ArgoCD will also self-heal if drift is detected.

---

## 7. Common Troubleshooting

**No new Freight after a successful CI pipeline:**
```bash
kargo refresh warehouse vroom-warehouse --project vroom
kubectl logs -n vroom-kargo -l app=kargo-controller --tail=100 | grep -i error
```

**Promotion stuck in `Running`:**
```bash
kargo get promotions --project vroom --stage dev
kubectl logs -n vroom-kargo -l app=kargo-controller --tail=200
```

**Verification `Failed` unexpectedly:**
```bash
kubectl get analysisruns -n vroom-kargo
kubectl describe analysisrun <run-name> -n vroom-kargo | grep -A 10 "Measurements"
```

**Re-run a failed verification:**
```bash
kargo refresh stage dev --project vroom
```
