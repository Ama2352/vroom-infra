# 🔐 SealedSecret Creation (Cluster-Based Workflow)

The standard way to use `kubeseal` in this project is **inside the cluster VM**. This avoids Windows PowerShell issues and ensures the CLI is always available.

### Step 1: Log into the Cluster VM

```powershell
vagrant ssh k3s-server
cd /vagrant
```

### Step 2: Seal the secrets (Run inside the VM)

Copy and paste these commands into the VM terminal:

```bash
# 1. User Service
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/user-db-secrets.vroom-dev.secret.yaml > .secrets/user-db-secrets.yaml

# 2. Ride Service
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/ride-db-secrets.vroom-dev.secret.yaml > .secrets/ride-db-secrets.yaml

# 3. Notification Service
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/notification-db-secrets.vroom-dev.secret.yaml > .secrets/notification-db-secrets.yaml
```

### Step 3: Move to GitOps (Run on Windows)

Exit the VM (`exit`) and run these on your Windows host to place the files in the correct GitOps directories:

```powershell
move .secrets/user-sealed.yaml ../vroom-gitops/apps/user/overlays/dev/secrets/user-db-secrets.yaml
move .secrets/ride-sealed.yaml ../vroom-gitops/apps/ride/overlays/dev/secrets/ride-db-secrets.yaml
move .secrets/notification-sealed.yaml ../vroom-gitops/apps/notification/overlays/dev/secrets/notification-db-secrets.yaml
```

---

**💡 If you need to re-fetch the cert (Inside VM):**

```bash
kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets --fetch-cert > .secrets/pub-cert.pem
```
