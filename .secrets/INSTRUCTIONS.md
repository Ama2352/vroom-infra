# 🔐 SealedSecret Creation (Strict Scope)

This project uses **Strict Scope** for all secrets, meaning each secret is tied to its specific name and namespace.

### Step 1: Log into the Cluster VM

```powershell
vagrant ssh k3s-server
cd /vagrant
```

### Step 1.5: Get the Public Certificate (If missing)

The public certificate is required to encrypt secrets. If `.secrets/pub-cert.pem` does not exist, fetch it from the cluster:

```bash
kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=sealed-secrets > .secrets/pub-cert.pem
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
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/platform/user-db-secrets.yaml > .secrets/platform-user-sealed.yaml
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/platform/ride-db-secrets.yaml > .secrets/platform-ride-sealed.yaml
kubeseal --cert .secrets/pub-cert.pem --format yaml < .secrets/platform/notification-db-secrets.yaml > .secrets/platform-notification-sealed.yaml
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

---

## New Secrets (Plans 02 & 03)

The following secrets are required before deploying the observability stack and AI reporter.
Always delete the plaintext `.yaml` files after sealing.

---

### 📦 monitoring — AlertManager Slack Secret

Replaces the `YOUR_SLACK_WEBHOOK_URL_HERE` placeholder. Required before deploying Loki/Tempo (Plan 02).

```bash
# Step 1: Create plaintext secret (inside vagrant ssh k3s-server, from /vagrant)
mkdir -p .secrets/monitoring
cat > .secrets/monitoring/alertmanager-slack-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-slack-secret
  namespace: monitoring
type: Opaque
stringData:
  slack-webhook-url: "<your-slack-webhook-url>"
EOF

# Step 2: Seal it
kubeseal --cert .secrets/pub-cert.pem \
         --scope strict \
         --format yaml \
         < .secrets/monitoring/alertmanager-slack-secret.yaml \
         > .secrets/monitoring-alertmanager-slack-sealed.yaml

# Step 3: Delete the plaintext file
rm .secrets/monitoring/alertmanager-slack-secret.yaml
exit
```

```powershell
# Step 4: Move to GitOps (Windows)
move .secrets\monitoring-alertmanager-slack-sealed.yaml `
     ..\vroom-gitops\infrastructure\observability\metrics\alertmanager-slack-secret.yaml
```

---

### 📦 vroom-dev — AI Reporter Secret

Required for the Gemini Flash AI reporter CronJob and Kargo verification job (Plan 03 & 05).

```bash
# Step 1: Create plaintext secret (inside vagrant ssh k3s-server, from /vagrant)
# Get a free Gemini API key at: https://aistudio.google.com/ → Get API Key
mkdir -p .secrets/vroom-dev
cat > .secrets/vroom-dev/ai-reporter-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ai-reporter-secret
  namespace: vroom-dev
type: Opaque
stringData:
  gemini-api-key: "<your-google-ai-studio-api-key>"
  slack-webhook-url: "<your-slack-webhook-url>"
EOF

# Step 2: Seal it
kubeseal --cert .secrets/pub-cert.pem \
         --scope strict \
         --format yaml \
         < .secrets/vroom-dev/ai-reporter-secret.yaml \
         > .secrets/vroom-dev-ai-reporter-sealed.yaml

# Step 3: Delete the plaintext file
rm .secrets/vroom-dev/ai-reporter-secret.yaml
exit
```

```powershell
# Step 4: Move to GitOps (Windows)
move .secrets\vroom-dev-ai-reporter-sealed.yaml `
     ..\vroom-gitops\apps\ai-reporter\secrets\ai-reporter-secret.yaml
```

---

### Summary of all secrets

| Secret name | Namespace | Keys | Plan | GitOps destination |
|-------------|-----------|------|------|--------------------|
| `user-db-secrets` | `vroom-dev` | DB credentials | existing | `apps/user/overlays/dev/secrets/` |
| `ride-db-secrets` | `vroom-dev` | DB credentials | existing | `apps/ride/overlays/dev/secrets/` |
| `notification-db-secrets` | `vroom-dev` | DB credentials | existing | `apps/notification/overlays/dev/secrets/` |
| `alertmanager-slack-secret` | `monitoring` | `slack-webhook-url` | 02 | `observability/metrics/alertmanager-slack-secret.yaml` |
| `ai-reporter-secret` | `vroom-dev` | `gemini-api-key`, `slack-webhook-url` | 03 | `apps/ai-reporter/secrets/ai-reporter-secret.yaml` |
