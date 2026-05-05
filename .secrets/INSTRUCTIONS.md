# 🔐 SealedSecret Creation (Strict Scope)

This project uses **Strict Scope** for all secrets, meaning each secret is tied to its specific name and namespace.

### Step 1: Log into the Cluster VM

```powershell
vagrant ssh k3s-server
cd /vagrant
```

### Step 2: Seal the secrets (Run inside the VM)

We organize secrets by namespace to ensure they are sealed correctly.

#### 📦 vroom-dev (Service Secrets)

```bash
# User Service
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/vroom-dev/user-db-secrets.yaml > .secrets/vroom-dev-user-sealed.yaml

# Ride Service
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/vroom-dev/ride-db-secrets.yaml > .secrets/vroom-dev-ride-sealed.yaml

# Notification Service
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/vroom-dev/notification-db-secrets.yaml > .secrets/vroom-dev-notification-sealed.yaml
```

#### 📦 platform (Postgres Management)

```bash
# Mirrored secrets for Postgres initialization
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/platform/user-db-secrets.yaml > .secrets/user-db-secrets.yaml
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/platform/ride-db-secrets.yaml > .secrets/ride-db-secrets.yaml
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/platform/notification-db-secrets.yaml > .secrets/notification-db-secrets.yaml
```

### Step 3: Move to GitOps (Run on Windows)

Exit the VM (`exit`) and move the sealed files to their final GitOps locations.

```powershell
# Move Service Secrets
move .secrets/vroom-dev-user-sealed.yaml ../vroom-gitops/apps/user/overlays/dev/secrets/user-db-secrets.yaml
move .secrets/vroom-dev-ride-sealed.yaml ../vroom-gitops/apps/ride/overlays/dev/secrets/ride-db-secrets.yaml
move .secrets/vroom-dev-notification-sealed.yaml ../vroom-gitops/apps/notification/overlays/dev/secrets/notification-db-secrets.yaml

# Move Infrastructure Secrets
move .secrets/platform-user-sealed.yaml ../vroom-gitops/infrastructure/postgres/secrets/user-db-secrets.yaml
move .secrets/platform-ride-sealed.yaml ../vroom-gitops/infrastructure/postgres/secrets/ride-db-secrets.yaml
move .secrets/platform-notification-sealed.yaml ../vroom-gitops/infrastructure/postgres/secrets/notification-db-secrets.yaml
```
